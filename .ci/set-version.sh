#!/bin/sh

cat Sources/tart/CI/CI.swift | envsubst | tee Sources/tart/CI/CI.swift
