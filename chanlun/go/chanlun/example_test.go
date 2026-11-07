package chanlun_test

import (
	"fmt"

	"github.com/zhifengzhang-sz/qi-v2-contracts/chanlun/go/chanlun"
)

// A run's JSON read, a record looked at, and the run written again as its canonical text.
func ExampleDecodeRun() {
	text := `{"merged": [{"end":0,"extremes":[0],"high":100.1,"index":0,"low":99.9,"mIndex":0,"start":0,"up":true}],
"fractals": [], "strokes": [], "segments": [], "moves": [], "consolidations": []}`
	run, err := chanlun.DecodeRun([]byte(text))
	if err != nil {
		fmt.Println(err)
		return
	}
	m := run.Merged.At(0)
	fmt.Println(m.High, m.High.Cmp(m.Low) > 0)
	canonical, _ := chanlun.EncodeRun(run)
	fmt.Print(canonical)
	// Output:
	// 100.1 true
	// {
	// "merged": [
	// {"end":0,"extremes":[0],"high":100.1,"index":0,"low":99.9,"mIndex":0,"start":0,"up":true}
	// ],
	// "fractals": [],
	// "strokes": [],
	// "segments": [],
	// "moves": [],
	// "consolidations": []
	// }
}
