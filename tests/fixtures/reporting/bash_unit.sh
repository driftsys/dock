#!/usr/bin/env bash
test_fixture_success() { assert_equals 1 1; }
test_fixture_failure() { assert_equals 1 2; }
