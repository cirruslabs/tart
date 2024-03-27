package fio

type Result struct {
	Jobs []Job `json:"jobs"`
}

type Job struct {
	Name  string `json:"jobname"`
	Write Write  `json:"write"`
}

type Write struct {
	BW   float64 `json:"bw"`
	IOPS float64 `json:"iops"`
}
