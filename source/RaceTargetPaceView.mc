import Toybox.Activity;
import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.WatchUi;

class RaceTargetPaceView extends WatchUi.DataField {
    var _paces as Array<String> = [];
    var _raceDistance as String = "marathon";
    var _maxMiles as Number = 1;
    var _currentMile as Number = 1;
    var _targetPace as String = "--";
    var _currentPace as String = "--";
    var _averagePace as String = "--";

    // Lap tracking (lap start is captured when the watch fires a lap, manual or auto)
    var _lapStartDistance as Float = 0.0;
    var _lapStartTime as Number = 0;
    var _lastDistance as Float = 0.0;
    var _lastTimerTime as Number = 0;

    // Set the label of the data field here.
    function initialize() {
        DataField.initialize();
        loadSettings();
    }

    function loadSettings() as Void {
        // Load race distance
        try {
            var distanceProp = Application.Properties.getValue("raceDistance");
            if (distanceProp != null) {
                _raceDistance = distanceProp.toString();
            } else {
                _raceDistance = "marathon";
            }
        } catch (e) {
            _raceDistance = "marathon";
            System.println("Error loading race distance: " + e);
        }
        
        // Determine max miles based on race distance
        var distanceNum = _raceDistance.toNumber();
        if (distanceNum == 0) {
            _maxMiles = 1;
        } else if (distanceNum == 1) {
            _maxMiles = 4;
        } else if (distanceNum == 2) {
            _maxMiles = 7;
        } else if (distanceNum == 3) {
            _maxMiles = 14;
        } else {
            _maxMiles = 27;
        }
        
        // Load pace settings
        _paces = new [_maxMiles];
        for (var i = 0; i < _maxMiles; i++) {
            try {
                var paceKey = "pace_" + (i + 1);
                var pace = Application.Properties.getValue(paceKey);
                if (pace != null) {
                    _paces[i] = pace.toString();
                } else {
                    _paces[i] = "12:00";
                }
            } catch (e) {
                _paces[i] = "12:00";
                System.println("Error loading pace " + (i+1) + ": " + e);
            }
        }
        
        System.println("Settings loaded - Distance: " + _raceDistance + ", Max Miles: " + _maxMiles);
    }

    // The given info object contains all the current workout
    // information. Calculate a value and return it in this method.
    // Note that compute() and onUpdate() are asynchronous, and there is no
    // guarantee that compute() will be called before onUpdate().
    function compute(info as Activity.Info) as Void {
        // See Activity.Info in the documentation for available information.
        var distance = info.elapsedDistance;
        // var distance = 1609.34 * 2.5; // For testing, simulate 2.5 miles completed

        if (distance == null) {
            _targetPace = "--";
            _currentPace = "--";
            return;
        }

        // Convert distance to miles
        var milesCompleted = distance / 1609.34;

        // Determine the current mile
        _currentMile = Math.floor(milesCompleted).toNumber() + 1;

        // Get target pace for the current mile
        if (_currentMile <= _maxMiles) {
            // Configured race distnace
            _targetPace = _paces[_currentMile - 1];
        } else {
            // Extra miles
            _targetPace = calculateAveragePace();
        }

        // Lap pace: time elapsed in the current lap divided by distance covered in it
        var timerTime = info.timerTime;
        _lastDistance = distance.toFloat();
        _lastTimerTime = timerTime != null ? timerTime : 0;

        var lapDistance = _lastDistance - _lapStartDistance;
        var lapSeconds = (_lastTimerTime - _lapStartTime) / 1000.0;

        // Wait for a little distance in the new lap so the pace isn't wildly off
        if (lapDistance > 10 && lapSeconds > 0) {
            // Convert to min/mile
            var paceSeconds = (lapSeconds / lapDistance * 1609.34).toNumber();
            var paceMinutes = paceSeconds / 60;
            var paceRemainingSeconds = paceSeconds % 60;

            _currentPace = paceMinutes.format("%d") + ":" + paceRemainingSeconds.format("%02d");
        } else {
            _currentPace = "--";
        }

        System.println("Mile: " + _currentMile + "/" + _maxMiles + ", Target: " + _targetPace + ", Current: " + _currentPace);

        return;
    }

    // Called when a lap is triggered (lap button or auto lap)
    function onTimerLap() as Void {
        _lapStartDistance = _lastDistance;
        _lapStartTime = _lastTimerTime;
    }

    // Called when the activity is reset; start lap tracking over
    function onTimerReset() as Void {
        _lapStartDistance = 0.0;
        _lapStartTime = 0;
        _lastDistance = 0.0;
        _lastTimerTime = 0;
        _currentPace = "--";
    }

    function calculateAveragePace() as String {
        // Calculate average pace from configured paces
        var totalSeconds = 0;
        var validPaces = 0;

        for (var i = 0; i < _maxMiles; i++) {
            var pace = _paces[i];
            var seconds = paceStringToSeconds(pace);

            if (seconds > 0) {
                totalSeconds += seconds;
                validPaces++;
            }
        }

        if (validPaces == 0) {
            return "12:00"; // Default pace
        }

        var avgSeconds = totalSeconds / validPaces;
        var minutes = Math.floor(avgSeconds / 60).toNumber();
        var seconds = Math.floor(avgSeconds % 60).toNumber();

        return minutes.format("%d") + ":" + seconds.format("%02d");
    }

    function paceStringToSeconds(pace as String) as Number {
        // Convert pace string "MM:SS" to total seconds
        var colonIndex = pace.find(":");
        if (colonIndex == null) {
            return 0;
        }

        var minuteStr = pace.substring(0, colonIndex);
        var secondStr = pace.substring(colonIndex + 1, pace.length());

        var minutes = minuteStr.toNumber();
        var seconds = secondStr.toNumber();

        if (minutes == null || seconds == null) {
            return 0;
        }

        return (minutes * 60) + seconds;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();

        // Set background color
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
        dc.clear();
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);

        // Draw mile indicator at top
        var mileLabel = "Mile " + _currentMile;
        if (_currentMile > _maxMiles) {
            mileLabel = "Mile " + _currentMile + " +";
        }
        dc.drawText(width / 2, 15, Graphics.FONT_MEDIUM, mileLabel, Graphics.TEXT_JUSTIFY_CENTER);

        // // Draw label at the top
        // dc.drawText(width / 2, 15, Graphics.FONT_MEDIUM, "Mile " + _currentMile, Graphics.TEXT_JUSTIFY_CENTER);

        // Draw target pace in the center, hot
        dc.drawText(width / 2, height / 2 - 65, Graphics.FONT_SYSTEM_NUMBER_HOT, _targetPace, Graphics.TEXT_JUSTIFY_CENTER);

        dc.drawText(width / 2, height / 2 - 10, Graphics.FONT_XTINY, "Target", Graphics.TEXT_JUSTIFY_CENTER);

        // Set the line color
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);

        // Draw a horizontal line across the middle
        // Example: From (0, screenHeight / 2) to (screenWidth, screenHeight / 2)
        dc.drawLine(0, height / 1.68, width, height / 1.68);

        // Draw current pace below
        dc.drawText(width / 2, height / 2 + 30, Graphics.FONT_SYSTEM_NUMBER_HOT, _currentPace, Graphics.TEXT_JUSTIFY_CENTER);

        dc.drawText(width / 2, height / 2 + 85, Graphics.FONT_XTINY, "Lap", Graphics.TEXT_JUSTIFY_CENTER);
    }

}