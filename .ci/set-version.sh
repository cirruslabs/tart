#!/bin/sh

TMPFILE=$(mktemp)
envsubst < Sources/tart/CI/CI.swift > $TMPFILE
cat $TMPFILE > Sources/tart/CI/CI.swift
