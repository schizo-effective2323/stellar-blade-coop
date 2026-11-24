// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// The pause menu's Online tab (ui/kit/pause_tab.lua draws it): SB's GameMenu logic takes its UI actions through its
// vtable slot 14, FUN_141d91500, which hands UI_RightShoulder to FUN_141d92440 and UI_LeftShoulder to FUN_141d921c0.
// The first walks the enabled tabs upward from the current one and wraps to the first, so RB on the last tab (Settings)
// goes to Equipment. The second walks them downward to 0, which FUN_141d926d0 turns into the highest enabled tab, so LB
// on the lowest enabled tab goes to Settings. The hook in its slot (ui/pause_tab_game.inc) asks Gate first: with SB's
// tab lock off, RB on the highest enabled tab and LB on the lowest one open SBO's page in place of the wrap, so the row
// reads as one ring of nine tabs; every other action reaches SB as before. To open SBO's menu, the Online tab closes
// the pause menu with SB's own close, FUN_141d90b80(logic, 0), as SB's Back (FUN_141d91500) and pause key
// (FUN_141fcac70) do: it runs the menu-close save when a tab asked for one (+0x18a) and the shown tab's deactivate
// before the UI manager hides the menu. glue/tick.cpp's coop_pause_close finds the logic as the pause key does: the UI
// manager's open entry of type 0x51 (FUN_141fc93f0), its logic at +0x60, checked by its vtable.
// The Online page (stage 1) is tab 9, a tab SB maps to no page: its init FUN_141d90210 fills the tab -> page TMap with
// tabs 1 to 8 only. coop_pause_enter does what SB's tab change FUN_141d926d0 does for the tab it leaves: it finds the
// shown tab's page in that map (page_of), runs the page's deactivate and writes 9 as the current tab. From tab 9 SB's
// previous asks 8, its next asks 10 (FUN_141d926d0 turns it into the lowest enabled tab) and a tab click asks its own
// tab. SB's close finds no page for 9. While tab 9 shows, the hook holds every action of SB's but the shoulders
// and the pause key: in slot 14 that only keeps Back from SB, so Lua takes Back on its page. coop_pause_page answers
// the open menu's tab for Lua's poll. The addresses and offsets are for Stellar Blade's Steam build 26123051. This
// part has no Windows call; tests/native/ui/pause_tab_test.cpp checks it.
#pragma once

#include <cstddef>
#include <cstdint>
#include <cstring>

namespace coop::pause_tab {

constexpr uint64_t kSlot = 0x145c26768;          // .rdata: the GameMenu logic's vtable 0x145c266f8 + 14 * 8.
constexpr uint64_t kInput = 0x141d91500;         // What the slot holds: the logic's UI action input.
constexpr uint64_t kRightShoulder = 0x146f52ee0; // The FName global of UI_RightShoulder, filled by SB at start.
constexpr size_t kCurrent = 0xb0;                // int32: the tab shown.
constexpr size_t kEnabled = 0xb8, kEnabledCount = 0xc0; // TArray<int32>: the tabs SB enabled, in any order.
constexpr size_t kLock = 0x188;                  // Byte: 1 while FUN_141d926d0 refuses every tab change.
constexpr size_t kEventName = 0x28;              // The action event's FName.
constexpr uint64_t kLatchMs = 500;               // A shoulder reaches the logic on press and on release: one open.
constexpr int32_t kMaxTabs = 16;                 // SB has 8 tabs; a longer list was not read from a GameMenu logic.
constexpr uint64_t kLogic = 0x145c266f8;         // The GameMenu logic's vtable.
constexpr int32_t kMenuType = 0x51;              // Its UI type: its vtable slot 2, FUN_141d8fbb0, returns it.
constexpr size_t kEntryLogic = 0x60;             // A UI manager entry's logic.
constexpr uint64_t kClose = 0x141d90b80;         // SB's close of the pause menu: (logic, 0 as Back passes).
constexpr uint64_t kLeftShoulder = 0x146f52ed8;  // The FName global of UI_LeftShoulder (FUN_14076ec90 fills it).
constexpr uint64_t kGameMenu = 0x146f52f38;      // The FName global of UI_GameMenu, the pause key (FUN_14076f4d0).
constexpr int32_t kPage = 9;                     // SBO's page: a tab FUN_141d926d0 maps to no page of SB's.
// The tab -> page logic TMap<int32, page *> at +0xc8, read as FUN_141d926d0 and FUN_141d90b80 read it.
constexpr size_t kPages = 0xc8;                  // Its entry array.
constexpr size_t kPagesNum = 0xd0, kPagesFree = 0xfc; // Equal: no entry, SB skips the lookup.
constexpr size_t kHashInline = 0x100, kHash = 0x108, kHashSize = 0x110; // Bucket heads (int32, -1: none).
constexpr size_t kEntrySize = 0x18, kEntryPage = 0x8, kEntryNext = 0x10; // An entry: tab +0, page +8, next +0x10.
constexpr size_t kPageCalls = 0xb0;              // A page logic's activate/deactivate object: this of both calls.
constexpr size_t kDeactivate = 0x20;             // Its vtable's deactivate, as called at 0x141d9284d.

// What coop_pause_close hands Lua, as its result count: SB's close ran, SB has no pause menu open, or off (not the
// pinned build, or after the tab's fault).
enum class Close : uint8_t { closed = 1, none = 2, off = 3 };

// What coop_pause_enter hands Lua: the page entered, already shown, SB has no pause menu open, SB's tab lock is on, or
// off (not the pinned build, coop off, or after the tab's fault).
enum class Enter : uint8_t { entered = 1, shown = 2, none = 3, locked = 4, off = 5 };
// What coop_pause_page hands Lua past the tabs 1 to 9: another number, SB has no pause menu open, or off.
enum class Tab : uint8_t { other = 10, none = 11, off = 12 };
inline int tab_answer(int32_t current) { return current >= 1 && current <= kPage ? current : int(Tab::other); }

// The action's FName against SB's globals: UI_RightShoulder, UI_LeftShoulder, UI_GameMenu (passes), or any other.
enum class Action : uint8_t { right_shoulder, left_shoulder, passes, other };
// SB's function runs, SBO's menu opens, nothing happens, or an SB action is kept from SBO's page (nothing happens).
enum class Verdict : uint8_t { pass, open, drop, held };

// One a hook, on the game thread only.
class Gate {
public:
  Verdict decide(int32_t current, const int32_t *enabled, int32_t count, uint8_t lock, Action action,
                 uint64_t now_ms) {
    if (current == kPage && action == Action::other)
      return Verdict::held;
    const bool next = action == Action::right_shoulder;
    if ((!next && action != Action::left_shoulder) || lock != 0)
      return Verdict::pass;
    if (opened_ && action == opened_by_ && now_ms - opened_at_ < kLatchMs)
      return Verdict::drop; // On any tab: the release of the press that opened, once Lua has entered tab 9.
    if (!enabled || count < 1 || count > kMaxTabs)
      return Verdict::pass;
    int32_t edge = enabled[0]; // RB: the highest enabled tab; LB: the lowest.
    for (int32_t i = 1; i < count; ++i)
      edge = (next ? enabled[i] > edge : enabled[i] < edge) ? enabled[i] : edge;
    if (current != edge)
      return Verdict::pass;
    opened_ = true, opened_by_ = action, opened_at_ = now_ms;
    return Verdict::open;
  }

private:
  bool opened_ = false;
  Action opened_by_ = Action::right_shoulder;
  uint64_t opened_at_ = 0;
};

template <class T> T read(uintptr_t where) {
  T value;
  std::memcpy(&value, reinterpret_cast<const void *>(where), sizeof value);
  return value;
}
// The page logic of a tab in the live GameMenu logic, or 0: the lookup FUN_141d926d0 makes, capped at kMaxTabs hops so
// a chain that loops ends. Raw reads only, under the caller's guard.
inline uintptr_t page_of(uintptr_t logic, int32_t tab) {
  if (read<int32_t>(logic + kPagesNum) == read<int32_t>(logic + kPagesFree))
    return 0;
  const uintptr_t hash = read<uintptr_t>(logic + kHash);
  const uintptr_t buckets = hash ? hash : logic + kHashInline;
  const int64_t bucket = (int64_t(read<int32_t>(logic + kHashSize)) - 1) & int64_t(tab);
  int32_t index = read<int32_t>(buckets + uintptr_t(bucket) * 4);
  const uintptr_t entries = read<uintptr_t>(logic + kPages);
  for (int32_t hop = 0; index != -1 && hop < kMaxTabs; ++hop) {
    const uintptr_t entry = entries + uintptr_t(int64_t(index) * int64_t(kEntrySize));
    if (read<int32_t>(entry) == tab)
      return read<uintptr_t>(entry + kEntryPage);
    index = read<int32_t>(entry + kEntryNext);
  }
  return 0;
}

} // namespace coop::pause_tab
