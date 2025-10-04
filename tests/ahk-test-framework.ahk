; Simple test framework for AutoHotkey v2
; Usage: Include this file and use Assert*, Describe, It functions

global TestResults := {
    Passed: 0,
    Failed: 0,
    CurrentSuite: "",
    CurrentTest: "",
    Failures: []
}

Describe(suiteName) {
    global TestResults
    TestResults.CurrentSuite := suiteName
    OutputDebug("Describe: " suiteName)
}

It(testName) {
    global TestResults
    TestResults.CurrentTest := testName
    OutputDebug("  It: " testName)
}

AssertEqual(actual, expected, message := "") {
    global TestResults
    if (actual != expected) {
        TestResults.Failed++
        failMsg := TestResults.CurrentSuite " > " TestResults.CurrentTest ": Expected '" expected "' but got '" actual "'"
        if (message != "")
            failMsg .= " (" message ")"
        TestResults.Failures.Push(failMsg)
        OutputDebug("    ❌ FAIL: " failMsg)
        return false
    }
    TestResults.Passed++
    OutputDebug("    ✓ Pass")
    return true
}

AssertTrue(condition, message := "") {
    global TestResults
    if (!condition) {
        TestResults.Failed++
        failMsg := TestResults.CurrentSuite " > " TestResults.CurrentTest ": Expected true but got false"
        if (message != "")
            failMsg .= " (" message ")"
        TestResults.Failures.Push(failMsg)
        OutputDebug("    ❌ FAIL: " failMsg)
        return false
    }
    TestResults.Passed++
    OutputDebug("    ✓ Pass")
    return true
}

AssertFalse(condition, message := "") {
    return AssertTrue(!condition, message)
}

AssertNotNull(value, message := "") {
    global TestResults
    if (value == "" || !IsSet(value)) {
        TestResults.Failed++
        failMsg := TestResults.CurrentSuite " > " TestResults.CurrentTest ": Expected non-null value"
        if (message != "")
            failMsg .= " (" message ")"
        TestResults.Failures.Push(failMsg)
        OutputDebug("    ❌ FAIL: " failMsg)
        return false
    }
    TestResults.Passed++
    OutputDebug("    ✓ Pass")
    return true
}

AssertIsObject(value, message := "") {
    global TestResults
    if (!IsObject(value)) {
        TestResults.Failed++
        failMsg := TestResults.CurrentSuite " > " TestResults.CurrentTest ": Expected object but got " Type(value)
        if (message != "")
            failMsg .= " (" message ")"
        TestResults.Failures.Push(failMsg)
        OutputDebug("    ❌ FAIL: " failMsg)
        return false
    }
    TestResults.Passed++
    OutputDebug("    ✓ Pass")
    return true
}

PrintTestResults() {
    global TestResults
    total := TestResults.Passed + TestResults.Failed
    
    OutputDebug("`n========================================")
    OutputDebug("Test Results")
    OutputDebug("========================================")
    OutputDebug("Total: " total)
    OutputDebug("Passed: " TestResults.Passed)
    OutputDebug("Failed: " TestResults.Failed)
    
    if (TestResults.Failed > 0) {
        OutputDebug("`nFailures:")
        for failure in TestResults.Failures {
            OutputDebug("  - " failure)
        }
    }
    
    OutputDebug("========================================")
    
    ; Also write to console
    FileAppend("Test Results: " TestResults.Passed "/" total " passed`n", "*")
    if (TestResults.Failed > 0) {
        FileAppend("FAILURES:`n", "*")
        for failure in TestResults.Failures {
            FileAppend("  " failure "`n", "*")
        }
    }
}

GetTestExitCode() {
    global TestResults
    return TestResults.Failed > 0 ? 1 : 0
}
