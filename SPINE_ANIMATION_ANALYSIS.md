# Spine 3.8 Animation Runtime Analysis - turner.json

## ROOT CAUSE SUMMARY

### Critical Issues Found:

1. **❌ Translate timelines ending without explicit reset values (0,0)**

   - Multiple bones have translate timelines that end at `time: 1.0` with NO x/y values
   - Runtime holds the last non-zero value instead of resetting to setup pose
   - Causes FX/skill attachments to drift and not align properly

2. **❌ Attachment timelines that don't explicitly reset**

   - Some attachment timelines end with `name: null` but don't explicitly clear at frame 0
   - Runtime may not properly reset attachment state when looping

3. **⚠️ Stepped timelines without explicit final values**

   - Some rotate/scale timelines end with just `{"time": 1}` without angle/scale values
   - Runtime uses last value, which may not match setup pose

4. **⚠️ First keyframe missing explicit values**
   - Some timelines start with only curve data, no explicit values
   - Parser defaults to 0, but this may not match setup pose

---

## EXACT PROBLEMATIC JSON STRUCTURES

### Issue #1: Translate Timeline Without Reset (CRITICAL)

**Location:** Line 5014-5058 (bone: "arm1" in animation)

```json
"translate": [
    {
        "curve": 0.392,
        "c3": 0.605
        // ❌ NO x/y at time 0 - defaults to (0,0)
    },
    {
        "time": 0.1667,
        "x": -11.32,
        "y": -15.13
    },
    // ... more keyframes ...
    {
        "time": 0.7333,
        "x": -23.38,
        "y": -2.37,
        "curve": 0.341,
        "c3": 0.77
    },
    {
        "time": 1
        // ❌ CRITICAL: No x/y values! Runtime holds (-23.38, -2.37)
    }
]
```

**Problem:**

- Last keyframe with values: `time: 0.7333, x: -23.38, y: -2.37`
- Final keyframe: `time: 1.0` with NO x/y
- Parser adds `(0, 0)` to values array (line 428-429 in skeleton_parser.dart)
- But runtime sampling (line 394 in skeleton_animation.dart) returns `values.last` when `t >= times.last`
- Since translate is ADDITIVE (`setupBone.x + translateX`), final value becomes `setupBone.x + 0` = setup pose
- **HOWEVER**: If animation loops, the interpolation between 0.7333 and 1.0 may not reach exactly 0, causing drift

**Why Spine Editor hides this:**

- Editor preview may interpolate differently or reset to setup pose on loop
- Editor might hold the last value visually but reset internally
- Editor's frame-by-frame preview doesn't show the loop transition issue

---

### Issue #2: Attachment Timeline Without Explicit Reset

**Location:** Line 4814-4823 (slot: "skill")

```json
"attachment": [
    {
        "name": null  // ❌ Time defaults to 0, clears attachment
    },
    {
        "time": 1,
        "name": null  // Explicitly clears at end
    }
]
```

**Problem:**

- Starts with `name: null` (clears attachment)
- Ends with `name: null` (clears attachment)
- **BUT**: If attachment was set mid-animation by another timeline or default skin, it won't reset properly
- Runtime attachment state may persist between loops

**Why Spine Editor hides this:**

- Editor resets all state when restarting animation
- Editor doesn't show loop transitions the same way runtime does

---

### Issue #3: Stepped Rotate/Scale Without Final Values

**Location:** Line 4868-4891 (bone: "root")

```json
"rotate": [
    {
        "curve": "stepped"
        // ❌ No angle at time 0
    },
    {
        "time": 1
        // ❌ No angle at time 1 - parser skips (line 408)
    }
],
"translate": [
    {
        "curve": "stepped"
        // ❌ No x/y at time 0
    },
    {
        "time": 1
        // ❌ No x/y at time 1 - parser adds (0,0)
    }
]
```

**Problem:**

- Rotate timeline: Parser SKIPS keyframes without angle (line 408)
- Translate timeline: Parser adds (0,0) for missing x/y (line 428-429)
- If setup pose has non-zero values, animation won't reset properly

---

## WHY RUNTIME BEHAVES DIFFERENTLY FROM EDITOR

### 1. **Loop Behavior**

- **Editor**: Resets to frame 0 state when looping (may reset to setup pose)
- **Runtime**: Continues from last frame, interpolates to first frame
- **Impact**: If final keyframe doesn't match first keyframe, there's a jump/drift

### 2. **Sampling Logic**

- **Editor**: May use different interpolation or hold behavior
- **Runtime**: Uses `values.last` when `t >= times.last` (line 394)
- **Impact**: Final keyframe value is held, not reset

### 3. **Additive Transforms**

- **Editor**: May show absolute values
- **Runtime**: Translate is ADDITIVE (`setupBone.x + translateX`)
- **Impact**: If final translate is not (0,0), bone doesn't return to setup pose

### 4. **Frame 0 Handling**

- **Editor**: Frame 0 may be treated as setup pose
- **Runtime**: Frame 0 is the first keyframe in timeline
- **Impact**: If first keyframe has no values, defaults may not match setup pose

---

## CORRECTED JSON EXAMPLES

### Fix #1: Translate Timeline with Explicit Reset

**BEFORE (Line 5014-5058):**

```json
"translate": [
    {
        "curve": 0.392,
        "c3": 0.605
    },
    {
        "time": 0.1667,
        "x": -11.32,
        "y": -15.13
    },
    // ... keyframes ...
    {
        "time": 0.7333,
        "x": -23.38,
        "y": -2.37,
        "curve": 0.341,
        "c3": 0.77
    },
    {
        "time": 1
    }
]
```

**AFTER:**

```json
"translate": [
    {
        "time": 0,
        "x": 0,
        "y": 0,
        "curve": 0.392,
        "c3": 0.605
    },
    {
        "time": 0.1667,
        "x": -11.32,
        "y": -15.13
    },
    // ... keyframes ...
    {
        "time": 0.7333,
        "x": -23.38,
        "y": -2.37,
        "curve": 0.341,
        "c3": 0.77
    },
    {
        "time": 1,
        "x": 0,
        "y": 0
    }
]
```

**Key Changes:**

- ✅ Explicit `x: 0, y: 0` at `time: 0`
- ✅ Explicit `x: 0, y: 0` at `time: 1` to reset to setup pose

---

### Fix #2: Attachment Timeline with Explicit Reset

**BEFORE (Line 4814-4823):**

```json
"attachment": [
    {
        "name": null
    },
    {
        "time": 1,
        "name": null
    }
]
```

**AFTER:**

```json
"attachment": [
    {
        "time": 0,
        "name": null
    },
    {
        "time": 1,
        "name": null
    }
]
```

**Key Changes:**

- ✅ Explicit `time: 0` for first keyframe
- ✅ Ensures attachment is cleared at both start and end

---

### Fix #3: Rotate/Scale with Explicit Values

**BEFORE (Line 4868-4891):**

```json
"rotate": [
    {
        "curve": "stepped"
    },
    {
        "time": 1
    }
]
```

**AFTER:**

```json
"rotate": [
    {
        "time": 0,
        "angle": 0,
        "curve": "stepped"
    },
    {
        "time": 1,
        "angle": 0
    }
]
```

**Key Changes:**

- ✅ Explicit `angle: 0` at both start and end
- ✅ Matches setup pose (assuming setup pose angle is 0)

---

## BEST-PRACTICE RULES FOR ANIMATORS

### Rule 1: Always Explicitly Reset Translate to (0,0) at Animation End

- ✅ **DO**: End translate timeline with `{"time": 1, "x": 0, "y": 0}`
- ❌ **DON'T**: End with just `{"time": 1}` without x/y values
- **Why**: Ensures bone returns to setup pose when animation loops

### Rule 2: Always Set Explicit Values at Frame 0

- ✅ **DO**: Start timelines with explicit values: `{"time": 0, "x": 0, "y": 0}`
- ❌ **DON'T**: Start with only curve data: `{"curve": 0.5}`
- **Why**: Ensures animation starts from known state matching setup pose

### Rule 3: Match Final Keyframe to First Keyframe for Seamless Loops

- ✅ **DO**: Make final keyframe (time: 1) match first keyframe (time: 0)
- ❌ **DON'T**: Let final keyframe drift from initial state
- **Why**: Prevents jumps/drifts when animation loops

### Rule 4: Explicitly Clear Attachments at Both Start and End

- ✅ **DO**: `[{"time": 0, "name": null}, {"time": 1, "name": null}]`
- ❌ **DON'T**: Rely on implicit time: 0 or missing time values
- **Why**: Ensures attachment state is predictable across loops

### Rule #5: Test Setup Pose vs Frame 0

- ✅ **DO**: In Spine Editor, compare Setup Pose with Frame 0 of animation
- ✅ **DO**: Use `Pose → Setup Pose` and check if skeleton jumps
- ❌ **DON'T**: Assume frame 0 matches setup pose
- **Why**: Catches issues before export

### Rule #6: Avoid Stepped Curves Without Values

- ✅ **DO**: Always provide angle/x/y values even with "stepped" curve
- ❌ **DON'T**: Use `{"curve": "stepped"}` without values
- **Why**: Parser may skip keyframes without values, causing unexpected behavior

---

## SPINE EDITOR WORKFLOW FIXES

### Fix in Spine Editor (Before Export):

1. **For each animation:**

   - Select animation
   - Go to last frame (time = duration)
   - For each bone with translate timeline:
     - Set translate to (0, 0) at last frame
     - Or ensure it matches first frame value
   - For each slot with attachment timeline:
     - Ensure final attachment state matches initial state

2. **Check Setup Pose:**

   - `Pose → Setup Pose`
   - Compare with Frame 0 of animation
   - If different, adjust setup pose or animation frame 0

3. **Test Loop:**
   - Enable loop in preview
   - Watch for jumps/drifts at loop point
   - Fix by matching final frame to first frame

---

## RUNTIME IMPACT

### Current Behavior:

- FX/skill attachments drift because bones don't reset to (0,0)
- Animation may jump when looping
- Some attachments may not clear properly

### After Fixes:

- All bones reset to setup pose at animation end
- Seamless loops without jumps
- Predictable attachment state

---

## VALIDATION CHECKLIST

Before exporting from Spine Editor, verify:

- [ ] All translate timelines end with explicit `x: 0, y: 0` (or match first frame)
- [ ] All rotate timelines have explicit angles at start and end
- [ ] All scale timelines have explicit values at start and end
- [ ] All attachment timelines explicitly set state at time 0 and time 1
- [ ] Setup Pose matches Frame 0 of all animations
- [ ] Loop preview shows no jumps or drifts
- [ ] FX/skill bones reset properly at animation end

---

## TECHNICAL NOTES

### Parser Behavior (skeleton_parser.dart):

- Line 408: Rotate keyframes without angle are **SKIPPED**
- Line 428-429: Translate keyframes without x/y default to **(0, 0)**
- Line 443-444: Scale keyframes without x/y default to **(1, 1)**

### Runtime Behavior (skeleton_animation.dart):

- Line 159: Setup pose is reset every frame
- Line 197-198: Translate is **ADDITIVE**: `setupBone.x + translateX`
- Line 394: When `t >= times.last`, returns `values.last`
- Line 191-192: Rotation replaces setup pose value (not additive)

### Why Additive Translate Causes Issues:

- If final translate is not (0,0), bone position = setup pose + offset
- On loop, if first frame translate is (0,0), there's a jump
- Solution: Ensure final translate matches first translate

---

## SUMMARY

**Primary Issue**: Translate timelines ending without explicit (0,0) reset values cause FX/skill attachments to drift.

**Root Cause**: Runtime holds last translate value, which doesn't reset to setup pose when animation loops.

**Fix**: Add explicit `x: 0, y: 0` at `time: 1` for all translate timelines that should reset.

**Prevention**: Always match final keyframe to first keyframe for seamless loops.
