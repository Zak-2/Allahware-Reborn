# Autoparry Functionality Deobfuscation and Analysis

This report focuses on the **Autoparry** functionality found within the `Features/Combat/Objects/Defender` module of the provided script. This module is the core of the script's automated defense system, handling parrying, dodging, and other defensive maneuvers.

The deobfuscated code reveals a highly complex, rule-based system designed to execute a perfect parry or intelligently fall back to other defensive actions based on real-time game state, configuration, and latency.

## 1. Deobfuscated Autoparry Code (`Defender.parry`)

The following is the deobfuscated `Defender.parry` function, with meaningful identifiers and internal commentary added to explain the logic flow.

\`\`\`lua
-- Main Parry Logic: Decides whether to parry, dodge, vent, or block based on incoming attack data
Defender.parry = LPH_NO_VIRTUALIZE(function(self, timing_data, action_data)
    -- 1. Initialize Dodge Options for potential fallback
    local dodge_opts = DodgeOptions.new()
    dodge_opts.rollCancel = Config.expectToggleValue("RollCancel")
    dodge_opts.rollCancelDelay = Config.expectOptionValue("RollCancelDelay") or 0
    dodge_opts.direct = Config.expectToggleValue("BlatantRoll")

    -- 2. Determine Dash/Dodge Instead of Parry Rate
    local dash_rate = Config.expectOptionValue("DashInsteadOfParryRate") or 0
    
    -- Check for per-attack overrides from the GUI/Library
    local override_data = Library:GetOverrideData(timing_data.name)
    if override_data then
        dash_rate = override_data.dipr -- Use override rate if available
    end

    -- 3. Check for existing Invincibility Frames (IFrames)
    local effect_rep = ReplicatedStorage:FindFirstChild("EffectReplicator")
    local effect_mod = effect_rep and require(effect_rep)
    local has_iframes = effect_mod:FindEffect("Immortal")
        or effect_mod:FindEffect("DodgeFrame")
        or effect_mod:FindEffect("ParryFrame")
        or effect_mod:FindEffect("Ghost")

    -- Determine if a dash/dodge should be performed instead of a parry based on the configured rate
    local should_dash = Random.new():NextNumber(1, 100) <= dash_rate

    -- 4. Override Dash/Dodge decision based on attack type and configuration
    -- L_34 is the obfuscated string for "Parry"
    if action_data and action_data._type ~= L_34 then
        should_dash = false -- Only dash instead of parry for parry-type actions
    end
    
    -- Check for "AllowFailure" or specific overrides to ensure dash is intentional
    if not Config.expectToggleValue("AllowFailure") and not override_data then
        should_dash = false
    end
    
    -- If the attack is unblockable/area-of-effect, or if multiple actions are queued, disable dash
    if timing_data.is_unblockable_or_area or timing_data.actions:count() ~= 1 then
        should_dash = false
    end

    -- 5. Notification Wrapper
    local notify_fn = function(...)
        -- Suppress notification if it's a silent repeatable event
        if timing_data.repeatable_event and timing_data.silent_report_no_notify then
            return
        end
        return self:notify(...)
    end

    -- Check if the player already has invincibility frames (IFrames) to avoid wasting a parry
    if Config.expectToggleValue("UseIFrames") and has_iframes then
        return notify_fn(timing_data, "Action 'Parry' blocked because there are already existing IFrames.")
    end

    -- 6. Primary Parry Attempt
    -- If parry is off cooldown, attempt to parry (deflect)
    if StateListener.can_parry() then
        -- Check if we should fall back to dodge/dash instead of parry
        if timing_data.no_fallback_dodge_block or not StateListener.can_dodge() or not should_dash then
            -- Execute the parry (which is implemented as a deflect action)
            return QueuedBlocking.invoke(QueuedBlocking.BLOCK_TYPE_DEFLECT, "Defender_Deflect", nil)
        end
        -- Fallback to dodge/dash if configured and randomly selected
        notify_fn(timing_data, "Action type 'Parry' replaced to 'Dodge' type.")
        return Input.dodge(dodge_opts)
    end

    -- 7. Fallback Logic (Parry is on cooldown)
    
    -- Check if Block is a valid fallback option
    local can_fallback_block = Config.expectToggleValue("DeflectBlockFallback") 
        and not timing_data.no_block_fallback 
        and StateListener.can_block()
        
    -- Check if Vent is a valid fallback option (Vent is a specific defensive move in Deepwoken)
    local can_fallback_vent = StateListener.can_vent()
        and Config.expectToggleValue("VentFallback")
        and not timing_data.no_vent_fallback
        and not timing_data.repeatable_event
        and self.__type ~= "Part"
        
    -- Check if Dodge is a valid fallback option (RollOnParryCooldown is a configuration toggle)
    local can_fallback_dodge = StateListener.can_dodge() 
        and Config.expectToggleValue("RollOnParryCooldown") 
        and not timing_data.no_dodge_fallback

    -- Prioritize Block Fallback if configured
    if timing_data.prefer_block_fallback and can_fallback_block then
        can_fallback_dodge = false
        can_fallback_vent = false
    end

    -- Execute Fallbacks in order of preference (Dodge -> Vent -> Block)
    if can_fallback_dodge then
        Input.dodge(dodge_opts)
        return notify_fn(timing_data, "Action type 'Parry' fallback to 'Dodge' type.")
    end
    
    if can_fallback_vent then
        Input.vent()
        return notify_fn(timing_data, "Action type 'Parry' fallback to 'Vent' type.")
    end
    
    if can_fallback_block then
        QueuedBlocking.invoke(QueuedBlocking.BLOCK_TYPE_NORMAL, "Defender_BlockFallback", timing_data.block_fallback_hit_time)
        return notify_fn(timing_data, "Action type 'Parry' fallback to 'Block' type.")
    end

    -- 8. Final Failure
    return notify_fn(timing_data, "Action 'Parry' blocked because no fallbacks are available.")
end)
\`\`\`

## 2. Explanation of Autoparry Functionality

The `Defender.parry` function is the core logic that executes the automated parry action. It is triggered by an incoming attack event (likely managed by the `repeatable_event` system) and performs a series of checks and fallbacks to ensure a successful defense.

### A. Pre-Execution Checks

Before attempting any action, the script performs several critical checks:

1.  **IFrame Check (Lines 610-612):** If the user is already protected by an invincibility frame (from an existing effect like `Immortal`, `DodgeFrame`, `ParryFrame`, or `Ghost`), the parry is blocked. This prevents redundant actions and conserves resources.
2.  **Dash/Dodge Rate (Lines 565-601):** The script supports a "Dash Instead Of Parry Rate" (`dash_rate`). A random number is generated, and if it falls within this rate, the script attempts to replace the parry with a dodge/dash. This is likely a feature to counter specific game mechanics or to add an element of "human-like" randomness.
3.  **Attack Type Filtering (Lines 584-595):** The script ensures that the dash-instead-of-parry logic only applies to attacks that are actually meant to be parried.

### B. Primary Action: Parry/Deflect (Lines 614-620)

If the `StateListener.can_parry()` check passes (meaning the parry is off cooldown), the script attempts the primary defense:

*   **Deflect:** If the dash-instead-of-parry condition is not met, the script executes a `QueuedBlocking.invoke` with `BLOCK_TYPE_DEFLECT`. In the context of Deepwoken, a successful parry is often referred to as a Deflect, which typically grants a brief stun or opening against the attacker.
*   **Dodge/Dash:** If the `dash_rate` condition is met, the script executes `Input.dodge(dodge_opts)` instead of the parry, logging that the action was "replaced to 'Dodge' type."

### C. Fallback System (Lines 621-644)

If the primary parry action is on cooldown (`StateListener.can_parry()` is false), the script initiates a complex fallback sequence based on user configuration:

| Fallback Action | Configuration Toggle | Condition | Purpose |
| :--- | :--- | :--- | :--- |
| **Dodge/Roll** | `RollOnParryCooldown` | `StateListener.can_dodge()` is true. | Used as a quick, invulnerable escape when a parry is not possible. |
| **Vent** | `VentFallback` | `StateListener.can_vent()` is true. | Executes a "Vent" action, which is a specific defensive move in the game (likely a stamina recovery or quick movement ability). |
| **Block** | `DeflectBlockFallback` | `StateListener.can_block()` is true. | The final defensive resort, invoking a normal block to mitigate damage. |

The script prioritizes these fallbacks in the order: **Dodge → Vent → Block**. It also includes a `prefer_block_fallback` toggle, which, if enabled, disables the Dodge and Vent fallbacks, forcing the script to use Block as the only alternative to a direct parry.

This multi-layered defense system ensures that the script attempts the most advantageous defense (Parry/Deflect) first, and if that fails due to cooldown, it seamlessly transitions to the next available defensive option, making the automated defense extremely robust.

## 3. Related Autoparry Code: Validation (`Defender.valid`)

The `Defender.valid` function (lines 163-256 in the deobfuscated file) is a crucial pre-check that determines if *any* automated defense action should be executed for a given incoming attack.

Key checks in this function include:

*   **Failure Rate:** A configurable `FailureRate` is checked against a random number. If the random number is low enough, the script intentionally fails to act, mimicking human error. This is controlled by the `AllowFailure` toggle.
*   **User State Filters:** The script checks if the user is in a state where automation should be disabled:
    *   Holding the Block key (`Disable While Holding Block`).
    *   Typing in a chat box (`Disable When Textbox Focused`).
    *   Using a specific move like 'Sightless Beam'.
    *   In a stun state (`User is in action stun.`).
    *   Knocked down (`User is knocked.`).
*   **Attack Filters:** The script allows filtering out specific attack types (M1s, Mantras, Criticals, Undefined) based on the `AutoDefenseFilters` configuration.
*   **Existing AutoParry Frames:** If the incoming action is a parry-type action, the script checks for an existing `AutoParry` effect on the user. If found, it blocks the action, as the game is already providing the necessary defense frames.

This validation function ensures that the `Defender.parry` logic is only called when all conditions are met for a successful and non-redundant automated defense.

***

The deobfuscated code for the `Defender` module, including the `parry` function and its dependencies, is attached for full review.
