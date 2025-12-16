#!/bin/bash

# Septentrio SBF Parser Validation Script
# Date: December 15, 2025
# Purpose: Verify that all 5 binary parsers are properly integrated and ready for testing

echo "================================================================"
echo "Septentrio SBF Parser Validation"
echo "================================================================"
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PASS_COUNT=0
FAIL_COUNT=0

# Function to check result
check_result() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓ PASS${NC}: $2"
        ((PASS_COUNT++))
    else
        echo -e "${RED}✗ FAIL${NC}: $2"
        ((FAIL_COUNT++))
    fi
}

echo "1. Checking Build Status"
echo "----------------------------------------"

# Check if package is built
if [ -f "/workspace/fgo_ws/install/septentrio_gnss_driver/lib/libseptentrio_gnss_driver_core.so" ]; then
    check_result 0 "Package septentrio_gnss_driver is built"
else
    check_result 1 "Package septentrio_gnss_driver is not built"
fi

echo ""
echo "2. Checking Message Definitions"
echo "----------------------------------------"

# Check for message files
MESSAGES=("GPSEPHEM" "GALFNAVEPHEMERIS" "IONUTC" "GALIONO" "GALCLOCK")
for msg in "${MESSAGES[@]}"; do
    if [ -f "/workspace/fgo_ws/src/gnssFGO/irt_gnss_preprocessing/driver_modification/septentrio_gnss_driver/msg/${msg}.msg" ]; then
        check_result 0 "Message file ${msg}.msg exists"
    else
        check_result 1 "Message file ${msg}.msg not found"
    fi
done

echo ""
echo "3. Checking Generated Message Headers"
echo "----------------------------------------"

# Check for generated C++ message headers
for msg in "${MESSAGES[@]}"; do
    msg_lower=$(echo "$msg" | tr '[:upper:]' '[:lower:]')
    if [ -f "/workspace/fgo_ws/install/septentrio_gnss_driver/include/septentrio_gnss_driver/septentrio_gnss_driver/msg/${msg_lower}.hpp" ]; then
        check_result 0 "Generated header ${msg_lower}.hpp exists"
    else
        check_result 1 "Generated header ${msg_lower}.hpp not found"
    fi
done

echo ""
echo "4. Checking Parser Implementations"
echo "----------------------------------------"

# Check if parsers exist in sbf_blocks.hpp
PARSER_FILE="/workspace/fgo_ws/src/gnssFGO/irt_gnss_preprocessing/driver_modification/septentrio_gnss_driver/include/septentrio_gnss_driver/parsers/sbf_blocks.hpp"

if grep -q "GPSNavParser" "$PARSER_FILE"; then
    check_result 0 "GPSNavParser (5891) implementation found"
else
    check_result 1 "GPSNavParser (5891) implementation not found"
fi

if grep -q "GALNavParser" "$PARSER_FILE"; then
    check_result 0 "GALNavParser (4002) implementation found"
else
    check_result 1 "GALNavParser (4002) implementation not found"
fi

if grep -q "GPSIonParser" "$PARSER_FILE"; then
    check_result 0 "GPSIonParser (5893) implementation found"
else
    check_result 1 "GPSIonParser (5893) implementation not found"
fi

if grep -q "GALIonParser" "$PARSER_FILE"; then
    check_result 0 "GALIonParser (4030) implementation found"
else
    check_result 1 "GALIonParser (4030) implementation not found"
fi

if grep -q "GALGstGpsParser" "$PARSER_FILE"; then
    check_result 0 "GALGstGpsParser (4032) implementation found"
else
    check_result 1 "GALGstGpsParser (4032) implementation not found"
fi

echo ""
echo "5. Checking Case Statements in message_handler.cpp"
echo "----------------------------------------"

HANDLER_FILE="/workspace/fgo_ws/src/gnssFGO/irt_gnss_preprocessing/driver_modification/septentrio_gnss_driver/src/septentrio_gnss_driver/communication/message_handler.cpp"

if grep -q "case GPS_NAV:" "$HANDLER_FILE"; then
    check_result 0 "Case GPS_NAV (5891) found in message_handler.cpp"
else
    check_result 1 "Case GPS_NAV (5891) not found"
fi

if grep -q "case GAL_NAV:" "$HANDLER_FILE"; then
    check_result 0 "Case GAL_NAV (4002) found in message_handler.cpp"
else
    check_result 1 "Case GAL_NAV (4002) not found"
fi

if grep -q "case GPS_ION:" "$HANDLER_FILE"; then
    check_result 0 "Case GPS_ION (5893) found in message_handler.cpp"
else
    check_result 1 "Case GPS_ION (5893) not found"
fi

if grep -q "case GAL_ION:" "$HANDLER_FILE"; then
    check_result 0 "Case GAL_ION (4030) found in message_handler.cpp"
else
    check_result 1 "Case GAL_ION (4030) not found"
fi

if grep -q "case GAL_GST_GPS:" "$HANDLER_FILE"; then
    check_result 0 "Case GAL_GST_GPS (4032) found in message_handler.cpp"
else
    check_result 1 "Case GAL_GST_GPS (4032) not found"
fi

echo ""
echo "6. Checking Configuration File"
echo "----------------------------------------"

CONFIG_FILE="/workspace/fgo_ws/install/septentrio_gnss_driver/share/septentrio_gnss_driver/config/rover.yaml"

if grep -q "gpsephem:" "$CONFIG_FILE"; then
    check_result 0 "Configuration parameter 'gpsephem' found"
else
    check_result 1 "Configuration parameter 'gpsephem' not found"
fi

if grep -q "galfnavephemeris:" "$CONFIG_FILE"; then
    check_result 0 "Configuration parameter 'galfnavephemeris' found"
else
    check_result 1 "Configuration parameter 'galfnavephemeris' not found"
fi

if grep -q "gpsion:" "$CONFIG_FILE"; then
    check_result 0 "Configuration parameter 'gpsion' found"
else
    check_result 1 "Configuration parameter 'gpsion' not found"
fi

if grep -q "galiono:" "$CONFIG_FILE"; then
    check_result 0 "Configuration parameter 'galiono' found"
else
    check_result 1 "Configuration parameter 'galiono' not found"
fi

if grep -q "galclock:" "$CONFIG_FILE"; then
    check_result 0 "Configuration parameter 'galclock' found"
else
    check_result 1 "Configuration parameter 'galclock' not found"
fi

echo ""
echo "7. Checking novatel_oem7_msgs Dependency"
echo "----------------------------------------"

if [ -d "/workspace/fgo_ws/install/novatel_oem7_msgs" ]; then
    check_result 0 "novatel_oem7_msgs package is installed"
else
    check_result 1 "novatel_oem7_msgs package not found"
fi

# Check CMakeLists.txt for dependency
CMAKE_FILE="/workspace/fgo_ws/src/gnssFGO/irt_gnss_preprocessing/driver_modification/septentrio_gnss_driver/CMakeLists.txt"
if grep -q "find_package(novatel_oem7_msgs REQUIRED)" "$CMAKE_FILE"; then
    check_result 0 "novatel_oem7_msgs dependency declared in CMakeLists.txt"
else
    check_result 1 "novatel_oem7_msgs dependency not declared"
fi

echo ""
echo "================================================================"
echo "VALIDATION SUMMARY"
echo "================================================================"
echo ""
echo -e "Total Checks: $(($PASS_COUNT + $FAIL_COUNT))"
echo -e "${GREEN}Passed: $PASS_COUNT${NC}"
echo -e "${RED}Failed: $FAIL_COUNT${NC}"
echo ""

if [ $FAIL_COUNT -eq 0 ]; then
    echo -e "${GREEN}✓ ALL CHECKS PASSED${NC}"
    echo ""
    echo "The Septentrio SBF parsers are properly integrated and ready for testing."
    echo ""
    echo "Next Steps:"
    echo "  1. Test with SBF log files (if available)"
    echo "  2. Test with live Septentrio receiver"
    echo "  3. Configure receiver to output navigation blocks:"
    echo "     setSBFOutput, Stream1, Ethernet, +GPSNav+GALNav+GPSIon+GALIon+GALGstGps, OnChange"
    echo "  4. Launch driver and verify topics:"
    echo "     ros2 launch septentrio_gnss_driver rover.launch.py"
    echo "     ros2 topic list | grep -E 'gpsephem|galfnav|gpsion|galion|galclock'"
    echo ""
    exit 0
else
    echo -e "${RED}✗ VALIDATION FAILED${NC}"
    echo ""
    echo "Please review the failed checks above and resolve issues before testing."
    echo ""
    exit 1
fi
