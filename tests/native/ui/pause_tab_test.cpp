// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// The Online tab's decision (ui/pause_tab.h), checked on the build machine: RB opens it only on the GameMenu logic's
// highest enabled tab and LB only on its lowest, while SB's tab lock is off; a list SB never builds passes on; one open
// a press and release of the same shoulder; the close is SB's own, its result counts the ones Lua reads. On the Online
// page (tab 9) SB's Back is held while the shoulders and the pause key reach SB. page_of finds a tab's page in a fake
// of SB's tab -> page TMap.
#include "ui/pause_tab.h"

#include <cassert>
#include <cstdio>
#include <cstring>

using namespace coop::pause_tab;

namespace {
// A fake GameMenu logic: the TMap's fields at their offsets, its entries and buckets apart.
struct Map {
  alignas(8) unsigned char logic[0x120] = {};
  alignas(8) unsigned char entries[8 * kEntrySize] = {};
  int32_t buckets[4] = {-1, -1, -1, -1};

  template <class T> void put(unsigned char *at, T value) { std::memcpy(at, &value, sizeof value); }
  Map(int32_t num, int32_t free, int32_t size, bool inline_hash) {
    put(logic + kPages, reinterpret_cast<uintptr_t>(entries));
    put(logic + kPagesNum, num);
    put(logic + kPagesFree, free);
    put(logic + kHash, inline_hash ? uintptr_t(0) : reinterpret_cast<uintptr_t>(buckets));
    put(logic + kHashInline, int32_t(-1));
    put(logic + kHashSize, size);
  }
  void entry(int32_t index, int32_t tab, uintptr_t page, int32_t next) {
    put(entries + index * kEntrySize, tab);
    put(entries + index * kEntrySize + kEntryPage, page);
    put(entries + index * kEntrySize + kEntryNext, next);
  }
  uintptr_t at() const { return reinterpret_cast<uintptr_t>(logic); }
};
} // namespace

int main() {
  static_assert(kSlot == 0x145c266f8 + 14 * 8 && kInput == 0x141d91500 && kRightShoulder == 0x146f52ee0);
  static_assert(kCurrent == 0xb0 && kEnabled == 0xb8 && kEnabledCount == 0xc0 && kLock == 0x188 && kEventName == 0x28);
  // The close: SB's own (what Back and the pause key run), on the logic found as the pause key finds it.
  static_assert(kClose == 0x141d90b80 && kSlot == kLogic + 14 * 8 && kMenuType == 0x51 && kEntryLogic == 0x60);
  static_assert(int(Close::closed) == 1 && int(Close::none) == 2 && int(Close::off) == 3); // Lua's result counts.
  // The Online page: the other two names slot 14 acts on, tab 9 and SB's tab -> page TMap with its deactivate call.
  static_assert(kLeftShoulder == 0x146f52ed8 && kGameMenu == 0x146f52f38 && kPage == 9);
  static_assert(kPages == 0xc8 && kPagesNum == 0xd0 && kPagesFree == 0xfc && kHashInline == 0x100 && kHash == 0x108 &&
                kHashSize == 0x110);
  static_assert(kEntrySize == 0x18 && kEntryPage == 8 && kEntryNext == 0x10);
  static_assert(kPageCalls == 0xb0 && kDeactivate == 0x20);
  static_assert(int(Enter::entered) == 1 && int(Enter::shown) == 2 && int(Enter::none) == 3 &&
                int(Enter::locked) == 4 && int(Enter::off) == 5); // coop_pause_enter's result counts.
  static_assert(int(Tab::other) == 10 && int(Tab::none) == 11 && int(Tab::off) == 12); // coop_pause_page's, past 9.
  const Action rb = Action::right_shoulder, lb = Action::left_shoulder, passes = Action::passes, other = Action::other;
  const int32_t all[] = {1, 2, 3, 4, 5, 6, 7, 8};
  { Gate g; assert(g.decide(8, all, 8, 0, rb, 1000) == Verdict::open); }      // RB on Settings.
  { Gate g; assert(g.decide(7, all, 8, 0, rb, 1000) == Verdict::pass); }      // Not the last tab.
  { Gate g; assert(g.decide(8, all, 8, 1, rb, 1000) == Verdict::pass); }      // SB's tab lock.
  { Gate g; assert(g.decide(8, all, 8, 0, passes, 1000) == Verdict::pass); }  // The pause key.
  // LB on the lowest enabled tab mirrors RB on the highest: SB's previous would wrap to Settings there.
  { Gate g; assert(g.decide(1, all, 8, 0, lb, 1000) == Verdict::open); }      // LB on Equipment.
  { Gate g; assert(g.decide(8, all, 8, 0, lb, 1000) == Verdict::pass); }      // LB on Settings: SB's previous.
  { Gate g; assert(g.decide(2, all, 8, 0, lb, 1000) == Verdict::pass); }      // Not the first tab.
  { Gate g; assert(g.decide(1, all, 8, 1, lb, 1000) == Verdict::pass); }      // SB's tab lock.
  { Gate g; assert(g.decide(1, all, 8, 0, rb, 1000) == Verdict::pass); }      // RB on Equipment: SB's next.
  { const int32_t no_first[] = {8, 3, 2}; Gate g; assert(g.decide(2, no_first, 3, 0, lb, 0) == Verdict::open); }
  { Gate g; assert(g.decide(9, all, 8, 0, lb, 1000) == Verdict::pass); }      // LB on the Online page: Settings.
  { Gate g; // An LB press and its release: one open; RB inside that latch is another press and reaches SB.
    assert(g.decide(1, all, 8, 0, lb, 1000) == Verdict::open);
    assert(g.decide(9, all, 8, 0, lb, 1100) == Verdict::drop && g.decide(9, all, 8, 0, rb, 1200) == Verdict::pass);
    assert(g.decide(9, all, 8, 0, lb, 1500) == Verdict::pass); // A later LB on the page: SB's previous, Settings.
  }
  { Gate g; // The RB latch keeps LB: an LB on Equipment just after RB opened still opens.
    assert(g.decide(8, all, 8, 0, rb, 1000) == Verdict::open && g.decide(1, all, 8, 0, lb, 1100) == Verdict::open);
  }
  { Gate g; assert(g.decide(8, all, 8, 0, other, 1000) == Verdict::pass); }   // Back on an SB page.
  { Gate g; assert(g.decide(9, all, 8, 0, rb, 1000) == Verdict::pass); }      // RB on the Online page: SB's next.
  { Gate g;                                                                    // A list SB never builds.
    assert(g.decide(8, all, 0, 0, rb, 0) == Verdict::pass && g.decide(8, all, 17, 0, rb, 0) == Verdict::pass &&
           g.decide(8, nullptr, 8, 0, rb, 0) == Verdict::pass); }
  { const int32_t some[] = {8, 1, 3}; Gate g; assert(g.decide(8, some, 3, 0, rb, 0) == Verdict::open); }
  { const int32_t no_map[] = {1, 2, 4, 5, 6, 7}; Gate g; assert(g.decide(7, no_map, 6, 0, rb, 0) == Verdict::open); }
  { Gate g; // A press and its release (the shoulders carry no type test): one open.
    assert(g.decide(8, all, 8, 0, rb, 1000) == Verdict::open);
    assert(g.decide(8, all, 8, 0, rb, 1100) == Verdict::drop && g.decide(8, all, 8, 0, rb, 1499) == Verdict::drop);
    assert(g.decide(8, all, 8, 1, rb, 1200) == Verdict::pass); // Inside the latch, SB's rules still pass it on.
    assert(g.decide(8, all, 8, 0, rb, 1500) == Verdict::open);
  }
  // On the Online page SB's Back is held, with or without the tab lock; the shoulders and the pause key reach SB.
  { Gate g; assert(g.decide(9, all, 8, 0, other, 1000) == Verdict::held); }
  { Gate g; assert(g.decide(9, all, 8, 1, other, 1000) == Verdict::held); }
  { Gate g; assert(g.decide(9, all, 8, 0, passes, 1000) == Verdict::pass); }
  { Gate g; // Lua entered the page after the open: the RB's release lands on tab 9 and is dropped, a later RB is SB's.
    assert(g.decide(8, all, 8, 0, rb, 1000) == Verdict::open);
    assert(g.decide(9, all, 8, 0, rb, 1100) == Verdict::drop);
    assert(g.decide(9, all, 8, 0, rb, 1500) == Verdict::pass);
  }
  // page_of, the lookup FUN_141d926d0 makes.
  {
    const uintptr_t equip = 0x1000, settings = 0x8000;
    Map m(2, 0, 4, false); // Two entries, four buckets: tab 8 and tab 4 share bucket 0, 8's entry behind 4's.
    m.entry(0, 8, settings, -1);
    m.entry(1, 4, equip, 0);
    m.buckets[0] = 1;
    assert(page_of(m.at(), 8) == settings && page_of(m.at(), 4) == equip);
    assert(page_of(m.at(), 9) == 0 && page_of(m.at(), 1) == 0); // Bucket 1 is empty.
    m.buckets[1] = 0;
    assert(page_of(m.at(), 9) == 0); // Bucket 1 holds 8's entry only: tab 9 is not in the chain.
  }
  {
    Map m(3, 3, 4, false); // Num equal to the free count: no entry, SB skips the lookup.
    m.entry(0, 8, 0x8000, -1);
    m.buckets[0] = 0;
    assert(page_of(m.at(), 8) == 0);
  }
  {
    Map m(1, 0, 1, true); // One bucket inline at +0x100 while +0x108 is 0.
    m.entry(0, 5, 0x5000, -1);
    m.put(m.logic + kHashInline, int32_t(0));
    assert(page_of(m.at(), 5) == 0x5000 && page_of(m.at(), 6) == 0);
  }
  {
    Map m(2, 0, 4, false); // A chain that loops on itself ends after kMaxTabs hops.
    m.entry(0, 4, 0x4000, 1);
    m.entry(1, 8, 0x8000, 0);
    m.buckets[1] = 0;
    assert(page_of(m.at(), 9) == 0);
  }
  assert(tab_answer(0) == 10 && tab_answer(1) == 1 && tab_answer(8) == 8 && tab_answer(9) == 9);
  assert(tab_answer(10) == 10 && tab_answer(12) == 10 && tab_answer(-1) == 10);
  std::puts("pause_tab_test ok");
  return 0;
}
