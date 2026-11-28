// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Part of glue/tick.cpp, one translation unit with it (see there).
// The pause menu's Online tab (ui/pause_tab.h, pause_tab_game.inc's hook): the worker's swap, undo, Lua's ask and
// the log.

namespace coop::pose {
namespace {
// One aligned 8-byte store into the GameMenu logic's vtable, as region_tabs_worker.inc makes: no instruction byte of
// the game changes. Made once a run by a compare-and-swap from SB's input only, undone at coop off and after a fault by
// a compare-and-swap from our hook only, so another mod's value is never overwritten. The DLL is pinned, so a thread
// still inside the hook after the undo is safe.
Filter pause_tab_state = Filter::untried; // The worker's.
bool pause_tab_fault_logged = false;
uint32_t pause_tab_opens_logged = 0, pause_tab_held_logged = 0;
uint64_t pause_tab_passed_logged = 0;

uint64_t pause_tab_original() { return base + (coop::pause_tab::kInput - game::kImageBase); }
uint64_t pause_tab_hook() { return reinterpret_cast<uintptr_t>(&pause_tab_input); }
// Once a run, on the pinned build before coop off. A slot that holds anything else is refused and never written: RB on
// Settings wraps to Equipment as in the game.
void pause_tab_install() {
  const uint64_t input = pause_tab_original();
  uint64_t held = *reinterpret_cast<const volatile uint64_t *>(base + (coop::pause_tab::kSlot - game::kImageBase));
  const bool slot_ok = held == input;
  const bool page_ok = slot_ok && swap_slot(coop::pause_tab::kSlot, input, pause_tab_hook(), held);
  const bool on = page_ok && held == input;
  pause_tab_state = on ? Filter::on : Filter::refused;
  pause_tab_live = on;
  if (on)
    say("pause tab on: 0x145c26768 swapped from the GameMenu logic's input to our hook");
  else if (slot_ok && !page_ok)
    say("pause tab refused: the page of 0x145c26768 would not become writable (error " +
        std::to_string(GetLastError()) + "); RB on Settings wraps to Equipment as in the game");
  else
    say("pause tab refused: 0x145c26768 holds " + slot_value(held) +
        ", not the GameMenu logic's input (another mod's hook?); left as it is, RB on Settings wraps to Equipment as "
        "in the game");
}
// The hook off first, then the slot back by a compare-and-swap from our hook only. If the swap cannot be made the hook
// stays and sends every call straight on.
void pause_tab_undo(const char *why) {
  if (pause_tab_state != Filter::on)
    return;
  pause_tab_state = Filter::off;
  pause_tab_live = false;
  uint64_t held = 0;
  if (!swap_slot(coop::pause_tab::kSlot, pause_tab_hook(), pause_tab_original(), held))
    say(std::string("pause tab off (") + why +
        "): the page of 0x145c26768 would not become writable; our hook stays in it and passes every action on");
  else if (held == pause_tab_hook())
    say(std::string("pause tab off (") + why + "): 0x145c26768 holds the GameMenu logic's input again");
  else
    say(std::string("pause tab off (") + why + "): 0x145c26768 holds " + slot_value(held) + ", left as it is");
}
// Each worker pass (from lion_pass): the swap once a run, a line for each new open and each new held action, the
// hook's fault once.
void pause_tab_pass() {
  if (pause_tab_state == Filter::untried && pinned && !blocked && !pause_tab_faulted)
    pause_tab_install();
  if (const uint32_t opens = pause_tab_opens; opens != pause_tab_opens_logged) {
    pause_tab_opens_logged = opens;
    say("pause tab: RB on Settings or LB on the first tab opened the Online tab (" + std::to_string(opens) +
        " this run)");
  }
  if (const uint64_t passed = pause_tab_passed; passed != pause_tab_passed_logged) {
    pause_tab_passed_logged = passed;
    if ((passed >> 32) <= 8) // Eight lines a run are enough to read the lock and the list.
      say(std::string("pause tab: ") + (passed & 1 ? "RB on tab " : "LB on tab ") +
          std::to_string(passed >> 24 & 0xff) + " went to SB (lock " + std::to_string(passed >> 16 & 0xff) + ", " +
          std::to_string(passed >> 8 & 0xff) + " tabs enabled)");
  }
  if (const uint32_t held = pause_tab_held; held != pause_tab_held_logged) {
    // One line as the count reaches 1, 10, 100 and so on: a held D-pad would write one at every pass.
    uint32_t step = 1;
    while (step <= held / 10)
      step *= 10;
    if (pause_tab_held_logged < step)
      say("pause tab: an action kept from SB on the Online page, Back or one SB ignores there (" +
          std::to_string(held) + " this run)");
    pause_tab_held_logged = held;
  }
  if (pause_tab_faulted && !pause_tab_fault_logged) {
    pause_tab_fault_logged = true;
    char text[300];
    std::snprintf(text, sizeof text, "pause tab fault 0x%08llx in %s reading 0x%llx: off for this run",
                  static_cast<unsigned long long>(pause_tab_fault_code.load()),
                  fault_where(pause_tab_fault_rva).c_str(),
                  static_cast<unsigned long long>(pause_tab_fault_address.load()));
    say(text);
    pause_tab_undo("a fault");
  }
}
} // namespace

// Lua's pausetab on or off (the pause_tab setting, or off when its tab button could not be made): the hook opens the
// Online tab only while on. A change is logged.
void ask_pause_tab(bool on) {
  if (pause_tab_want.exchange(on) != on)
    say(on ? std::string("pause tab: asked on, RB on Settings opens the Online tab")
           : std::string("pause tab: asked off, RB on Settings wraps to Equipment as in the game"));
}
} // namespace coop::pose
