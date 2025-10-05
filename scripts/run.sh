#!/bin/bash

if [ $# -lt 3 ]; then
    echo "Usage: $0 <benchmark-id> <reflection-mode> <enable-reflection-log (en|dis)>"
    exit 1
fi

BENCHMARK_ID=$1
REFL_MODE=$2
EN_REFL_LOG=$3
TAI_E_PATH="/SSD3/asun/Tai-e"
INFO_FILE="$TAI_E_PATH/java-benchmarks/benchmark-info.yml"
JAR_PATH="$TAI_E_PATH//build/tai-e-all-0.5.2-SNAPSHOT.jar"

if [ ! -f "$INFO_FILE" ]; then
    echo "Error: Benchmark info file not found: $INFO_FILE"
    exit 1
fi

if [ ! -f "$JAR_PATH" ]; then
    echo "Error: JAR file not found: $JAR_PATH"
    exit 1
fi

get_yaml_value() {
    local field=$1
    local id=$2
    local file=$3
    local pattern="^- id: ${id}$"
    local line_num=$(grep -n "$pattern" "$file" | cut -d ':' -f1)

    if [ -z "$line_num" ]; then
        echo "Error: Benchmark ID '$id' not found in $file"
        exit 1
    fi

    local next_id_line=$(grep -n "^- id:" "$file" | awk -F: '$1 > '"$line_num"' {print $1; exit}')
    if [ -z "$next_id_line" ]; then
        next_id_line=$(wc -l < "$file")
        next_id_line=$((next_id_line + 1))
    fi

    local result=$(sed -n "$line_num,$next_id_line p" "$file" | grep "^ \+$field:" | head -1 | sed "s/^ \+$field: \[ \(.*\) \]/\1/" | sed "s/^ \+$field: \(.*\)/\1/")
    echo "$result"
}

JDK=$(get_yaml_value "jdk" "$BENCHMARK_ID" "$INFO_FILE")
MAIN=$(get_yaml_value "main" "$BENCHMARK_ID" "$INFO_FILE")
APPS=$(get_yaml_value "apps" "$BENCHMARK_ID" "$INFO_FILE")
LIBS=$(get_yaml_value "libs" "$BENCHMARK_ID" "$INFO_FILE")
REFL_LOG=$(get_yaml_value "refl-log" "$BENCHMARK_ID" "$INFO_FILE")

APP_PATHS=""
for app in $(echo "$APPS" | tr ',' ' '); do
    app=$(echo "$app" | tr -d ' ' | sed "s/'//g" | sed 's/"//g')
    if [ ! -z "$app" ]; then
        APP_PATHS="$TAI_E_PATH/java-benchmarks/$app,"
    fi
done
APP_PATHS=${APP_PATHS%,}

LIB_PATHS=""
for lib in $(echo "$LIBS" | tr ',' ' '); do
    lib=$(echo "$lib" | tr -d ' ' | sed "s/'//g" | sed 's/"//g')
    if [ ! -z "$lib" ]; then
        LIB_PATHS="$TAI_E_PATH/java-benchmarks/$lib,"
    fi
done
LIB_PATHS=${LIB_PATHS%,}

REFL_LOG_PARAM=""
if [ ! -z "$REFL_LOG" ]; then
    REFL_LOG=$(echo "$REFL_LOG" | tr -d ' ' | sed "s/'//g" | sed 's/"//g')
    REFL_LOG="$TAI_E_PATH/java-benchmarks/$REFL_LOG"
    REFL_LOG_PARAM="reflection-log:$REFL_LOG"
fi

if [ "$EN_REFL_LOG" = "dis" ]; then
    REFL_LOG_PARAM=""
fi

echo "Running analysis for $BENCHMARK_ID..."
java -Xmx32g -jar "$JAR_PATH" \
    -acp "$APP_PATHS" \
    -cp "$LIB_PATHS" \
    -ap \
    -java "$JDK" \
    -m "$MAIN" \
    -a pta="only-app:false;distinguish-string-constants:all;$REFL_LOG_PARAM;reflection-inference:$REFL_MODE;plugins:[]" \
    -a poly-call

echo "Analysis completed for $BENCHMARK_ID"
