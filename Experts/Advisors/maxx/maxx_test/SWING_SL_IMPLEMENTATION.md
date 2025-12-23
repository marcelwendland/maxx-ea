# Swing HIGH/LOW SL with ATR Offset - Implementation Summary

## Overview
Dynamic Stop Loss strategy using ZigZag indicator to identify swing HIGH/LOW points, offset by ATR × multiplier, with comprehensive chart visualization and trade validation.

## Features Implemented

### 1. ZigZag Indicator Integration (Strategy.mqh)
- **Handle**: `zigzagHandle` added to namespace globals
- **Initialization**: Created using `iCustom()` with "ZigZag" indicator
- **Parameters**: Depth=12, Deviation=5, Backstep=3 (configurable)
- **Validation**: Requires `InpUseATR = true` (logs error and returns false if disabled)
- **Cleanup**: Released in `Deinit()` with `DeleteAllChartObjects()`

### 2. Configurable Parameters (Params.mqh:47-60)
```cpp
//| ZigZag Settings for Swing Detection
input int InpZigZag_Depth     = 12;    // ZigZag Depth
input int InpZigZag_Deviation = 5;     // ZigZag Deviation  
input int InpZigZag_Backstep  = 3;     // ZigZag Backstep
```

### 3. Swing Detection Logic (Strategy.mqh)
**Function**: `FindLastZigZagSwing(symbol, signal, &swingPrice, &swingBarIndex)`

**Process**:
- Copies ZigZag buffer 0 backwards from bar 1
- Searches up to `InpMA_SlowPeriod × 2` bars
- Finds first non-zero ZigZag value
- **For BUY**: Validates it's a swing LOW (trough) by comparing to bar's high/low
- **For SELL**: Validates it's a swing HIGH (peak)
- Returns true with price and bar index, or false if not found

**Validation Method**:
- Compares ZigZag point against bar's High/Low values
- Uses distance comparison: `MathAbs(swingPrice - low)` vs `MathAbs(swingPrice - high)`
- Ensures correct swing type for trade direction

### 4. Enhanced SL Calculation (Strategy.mqh:297-380)
**Function**: `CalculateSL(symbol, signal)`

**Steps**:
1. Validates ATR is enabled and available
2. Copies ATR buffer from last closed bar
3. Calls `FindLastZigZagSwing()` to get swing point
4. Stores swing info in namespace variables for visualization:
   - `lastSwingPrice`
   - `lastSwingBarIndex`
   - `lastSwingIsHigh`
5. Calculates SL with ATR offset:
   - **BUY**: `sl = swingPrice - (atrValue × InpATR_Multiplier)`
   - **SELL**: `sl = swingPrice + (atrValue × InpATR_Multiplier)`
6. Validates against broker's minimum stop level (`SYMBOL_TRADE_STOPS_LEVEL`)
7. Returns normalized SL price or -1.0 if invalid

**Comprehensive Logging**:
- ATR value used
- Swing point found (bar index, price, type)
- Calculated SL with formula breakdown
- Broker minimum stop level comparison
- Specific skip reasons (no swing, stop level violation)

### 5. Dual Chart Visualization (Strategy.mqh:382-491)

#### DrawSLLine(ticket, slPrice)
- **Object Type**: `OBJ_HLINE` (horizontal line)
- **Name**: `"SL_Line_" + ticket`
- **Style**: Red color, solid line, width 2
- **Text**: `"SL: [price]"`

#### DrawSwingArrow(ticket, barIndex, price, isHigh)
- **Object Type**: `OBJ_ARROW`
- **Name**: `"Swing_Arrow_" + ticket`
- **Position**: Exact bar time of swing point
- **Arrow Codes**:
  - 218 (up arrow) for swing LOWs on BUY trades
  - 217 (down arrow) for swing HIGHs on SELL trades
- **Style**: Red color, width 3
- **Text**: `"Swing HIGH"` or `"Swing LOW"`

#### DeleteTradeObjects(ticket)
- Removes both SL line and swing arrow for specific ticket
- Called when position closes
- Logs deletion confirmation

#### DeleteAllChartObjects()
- Cleanup all SL and swing objects on EA deinit
- Iterates through all chart objects
- Removes objects with "SL_Line_" or "Swing_Arrow_" prefix

### 6. Updated Trade Execution (maxx_test.mq5:71-140)

**Enhanced OnTick() Logic**:
1. Get signal from strategy
2. Calculate SL using `Strategy::CalculateSL()`
3. **Validate SL > 0** (skip trade if ≤ 0)
4. Log skip reason: "Invalid swing/SL (ZigZag or stop level)"
5. Calculate actual SL distance in points: `MathAbs((entry_price - sl) / _Point)`
6. Pass to `Orders::CalculateLotSize()` for dynamic position sizing
7. Execute order (BuyMarket/SellMarket)
8. **On success**:
   - Retrieve position ticket via `Orders::GetPositionTicket()`
   - Get swing info via `Strategy::GetLastSwingInfo()`
   - Call `Strategy::DrawSLLine(ticket, sl)`
   - Call `Strategy::DrawSwingArrow(ticket, barIndex, swingPrice, isHigh)`
   - Log chart object creation

### 7. OnTradeTransaction() Handler (maxx_test.mq5:142-173)

**Event Detection**:
- Monitors `TRADE_TRANSACTION_DEAL_DELETE` and `TRADE_TRANSACTION_HISTORY_ADD`
- Filters by EA magic number (`InpMagicNumber`)
- Checks if deal is an exit: `DEAL_ENTRY_OUT` or `DEAL_ENTRY_OUT_BY`

**Cleanup Process**:
- Extracts position ID from deal
- Calls `Strategy::DeleteTradeObjects(positionId)`
- Removes both SL line and swing arrow markers
- Logs position closure and object removal

## Trade Skip Scenarios

The EA will **skip trades** in the following cases:

1. **ATR Disabled**: If `InpUseATR = false` (logged at initialization)
2. **No Swing Point**: ZigZag doesn't find valid HIGH/LOW in lookback period
3. **Wrong Swing Type**: Found swing is not appropriate for signal direction
4. **Stop Level Violation**: Calculated SL distance < broker's minimum stop level
5. **Invalid SL**: Any other condition that results in `CalculateSL()` returning -1.0

Each skip is logged with specific reason for easy troubleshooting.

## Object Naming Convention

**Ticket-Based Naming** enables precise cleanup:
- `SL_Line_12345` - SL line for position ticket 12345
- `Swing_Arrow_12345` - Swing arrow for position ticket 12345

This allows:
- Multiple positions to have separate visualizations
- Clean removal of specific position's objects when it closes
- Persistence of active trade visualizations

## Logging Structure

### Initialization Logs
- ZigZag creation success with parameters
- MA initialization with periods and method
- ATR availability check

### Per-Trade Logs
- **Swing Detection**: Bar index, price, HIGH/LOW type
- **ATR Value**: Current ATR reading
- **SL Calculation**: Full formula breakdown
- **Broker Validation**: Minimum stop level vs calculated distance
- **Skip Reasons**: Specific explanation when trade rejected
- **Execution**: Order success/failure with ticket
- **Visualization**: Chart object creation confirmation

### Cleanup Logs
- Position closure detection
- Object deletion for specific ticket
- Complete cleanup on EA deinit

## Visual Indicators on Chart

When active, the EA displays:
1. **Red Horizontal Line**: Current Stop Loss price
2. **Red Arrow Marker**: 
   - Down arrow (▼) at swing HIGH for SELL trades
   - Up arrow (▲) at swing LOW for BUY trades
3. Both objects auto-remove when position closes

## Configuration Requirements

**Mandatory Settings**:
- `InpUseATR = true` (EA will refuse to initialize if false)
- Valid ZigZag parameters (Depth, Deviation, Backstep)
- ATR Period and Multiplier configured

**Recommended Settings**:
- `InpZigZag_Depth = 12` (default, adjust for timeframe)
- `InpATR_Multiplier = 2.0 to 3.0` (provides reasonable offset)
- `InpATR_Period = 14` (standard ATR period)

## Files Modified

1. **Params.mqh** (lines 47-60): Added ZigZag parameters
2. **Strategy.mqh** (complete refactor):
   - Added ZigZag handle and swing tracking variables
   - Enhanced Init() with ATR validation and ZigZag creation
   - Implemented FindLastZigZagSwing()
   - Refactored CalculateSL() with swing detection
   - Added 4 visualization functions
   - Enhanced Deinit() with object cleanup
3. **maxx_test.mq5** (lines 71-173):
   - Enhanced OnTick() with SL validation and visualization
   - Added OnTradeTransaction() handler for cleanup

## Testing Checklist

- [ ] EA initializes successfully with `InpUseATR = true`
- [ ] EA refuses initialization with `InpUseATR = false`
- [ ] ZigZag swing points detected correctly for signal direction
- [ ] SL calculated with proper ATR offset
- [ ] Broker stop level violations logged and trades skipped
- [ ] Red SL line appears on chart when position opens
- [ ] Red arrow marker appears at swing point
- [ ] Both objects disappear when position closes
- [ ] Multiple positions show separate visualizations
- [ ] All objects cleaned up on EA deinit

## Performance Considerations

- **Efficient Buffer Management**: Single ZigZag buffer copy per signal
- **Minimal Lookback**: Limited to `InpMA_SlowPeriod × 2` bars
- **Object Cleanup**: Ticket-based removal prevents orphaned objects
- **Event-Driven**: OnTradeTransaction() only processes relevant deals

## Future Enhancements (Optional)

- Configurable arrow colors per trade direction
- SL line style/color configuration
- Text labels showing ATR multiplier used
- Historical swing point markers retention
- Alert notifications on swing SL violations
