package fio

type Result struct {
	Jobs []Job `json:"jobs"`
}

type Job struct {
	Name  string `json:"jobname"`
	Read  Stats  `json:"read"`
	Write Stats  `json:"write"`
}

type Stats struct {
	BW   float64 `json:"bw"`
	IOPS float64 `json:"iops"`
}
