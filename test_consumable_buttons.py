#!/usr/bin/env python3
"""
Test script for EmptyShelvesConsumable button behavior
This simulates the button state logic to verify our fixes work correctly.
"""

class MockConsumableIcon:
    def __init__(self):
        self.is_useable = False
        self._sell_button_visible = False
        self._use_button_visible = False
        self.sell_button_visible = False
        self.use_button_visible = False
        self.use_button_disabled = True
        
    def _on_pressed(self):
        """Simulate the card being pressed to toggle buttons"""
        print(f"Before press: sell_visible={self._sell_button_visible}, use_visible={self._use_button_visible}")
        
        # Toggle buttons visibility
        self._sell_button_visible = not self._sell_button_visible
        self._use_button_visible = not self._use_button_visible
        
        # Apply sell button logic
        self.sell_button_visible = self._sell_button_visible
        
        # Apply use button logic (new fixed logic)
        self.use_button_visible = self._use_button_visible
        self.use_button_disabled = not self.is_useable
        
        print(f"After press: sell_visible={self._sell_button_visible}, use_visible={self._use_button_visible}")
        print(f"Button states: sell_visible={self.sell_button_visible}, use_visible={self.use_button_visible}, use_disabled={self.use_button_disabled}")
        
    def set_useable(self, useable):
        """Simulate setting usability"""
        print(f"Setting useable to: {useable}")
        self.is_useable = useable
        
        # Update use button state - keep visible but disable if not useable
        if self._use_button_visible:
            self.use_button_disabled = not self.is_useable
            print(f"Updated use button: visible={self.use_button_visible}, disabled={self.use_button_disabled}")

def test_button_behavior():
    print("=== Testing ConsumableIcon Button Behavior ===\n")
    
    icon = MockConsumableIcon()
    
    print("1. Initial state (not useable, not pressed):")
    print(f"   sell_visible={icon.sell_button_visible}, use_visible={icon.use_button_visible}, use_disabled={icon.use_button_disabled}\n")
    
    print("2. Press card (should show buttons but use button disabled):")
    icon._on_pressed()
    print()
    
    print("3. Make consumable useable (should enable use button):")
    icon.set_useable(True)
    print()
    
    print("4. Make consumable not useable (should disable use button but keep visible):")
    icon.set_useable(False)
    print()
    
    print("5. Press card again (should hide buttons):")
    icon._on_pressed()
    print()
    
    print("6. Press card again (should show buttons, use disabled since not useable):")
    icon._on_pressed()
    print()

if __name__ == "__main__":
    test_button_behavior()