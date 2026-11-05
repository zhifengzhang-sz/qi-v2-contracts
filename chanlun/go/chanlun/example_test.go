package chanlun_test

import (
	"fmt"

	"github.com/zhifengzhang-sz/qi-v2-contracts/chanlun/go/chanlun"
)

// A run's JSON read, a record looked at, and the run written again as its canonical text.
func ExampleDecodeRun() {
	text := `{"klines": [{"close":100.05,"date":1767623400000,"high":100.1,"index":0,"low":99.9,"open":100,"volume":1}],
"merged": [], "fractals": [], "strokes": [], "segments": [], "moves": [], "consolidations": []}`
	run, err := chanlun.DecodeRun([]byte(text))
	if err != nil {
		fmt.Println(err)
		return
	}
	k := run.Klines.At(0)
	fmt.Println(k.High, k.High.Cmp(k.Close) > 0)
	canonical, _ := chanlun.EncodeRun(run)
	fmt.Print(canonical)
	// Output:
	// 100.1 true
	// {
	// "klines": [
	// {"close":100.05,"date":1767623400000,"high":100.1,"index":0,"low":99.9,"open":100,"volume":1}
	// ],
	// "merged": [],
	// "fractals": [],
	// "strokes": [],
	// "segments": [],
	// "moves": [],
	// "consolidations": []
	// }
}
