package fio

import (
	"fmt"
	"time"
)

type Result struct {
	Jobs []Job `json:"jobs"`
}

type Job struct {
	Name  string `json:"jobname"`
	Read  Stats  `json:"read"`
	Write Stats  `json:"write"`
	Sync  Stats  `json:"sync"`
}

type Stats struct {
	BW        float64 `json:"bw"`
	IOPS      float64 `json:"iops"`
	LatencyNS Latency `json:"lat_ns"`
}

type Latency struct {
	Mean   float64 `json:"mean"`
	Stddev float64 `json:"stddev"`
}

func (latency Latency) String() string {
	meanDuration := time.Duration(latency.Mean) * time.Nanosecond
	stddevDuration := time.Duration(latency.Stddev) * time.Nanosecond

	return fmt.Sprintf("%v ± %v", meanDuration, stddevDuration)
}
