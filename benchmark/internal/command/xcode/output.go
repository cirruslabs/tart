package xcode

import (
	"fmt"
	"regexp"
	"time"
)

type Output struct {
	Started time.Time
	Ended   time.Time
}

func ParseOutput(s string) (*Output, error) {
	// Ensure that the build has succeeded
	matched, err := regexp.MatchString("(?m)^\\*\\* BUILD SUCCEEDED \\*\\*.*$", s)
	if err != nil {
		return nil, fmt.Errorf("failed to parse output: regexp failed: %v", err)
	}
	if !matched {
		return nil, fmt.Errorf("failed to parse output: \"** BUILD SUCCEEDED **\" string " +
			"not found on a separate line, make sure you have Xcode installed")
	}

	re := regexp.MustCompile("Started\\s+(?P<started>.*)\\n.*Ended\\s+(?P<ended>.*)\\n")

	matches := re.FindStringSubmatch(s)

	if len(matches) != re.NumSubexp()+1 {
		return nil, fmt.Errorf("failed to parse output: cannot find Started and Ended times")
	}

	startedRaw := matches[re.SubexpIndex("started")]
	started, err := time.Parse(time.TimeOnly, startedRaw)
	if err != nil {
		return nil, fmt.Errorf("failed to parse started time %q: unsupported format", startedRaw)
	}

	endedRaw := matches[re.SubexpIndex("ended")]
	ended, err := time.Parse(time.TimeOnly, endedRaw)
	if err != nil {
		return nil, fmt.Errorf("failed to parse ended time %q: unsupported format", startedRaw)
	}

	return &Output{
		Started: started,
		Ended:   ended,
	}, nil
}
