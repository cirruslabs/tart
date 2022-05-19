#!/bin/sh

TMPFILE=$(mktemp)
envsubst < Sources/tart/CI/CI.swift > $TMPFILE
mv $TMPFILE Sources/tart/CI/CI.swift
