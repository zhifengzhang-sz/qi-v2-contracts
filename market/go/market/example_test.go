package market_test

import (
	"fmt"

	"github.com/zhifengzhang-sz/qi-v2-contracts/market/go/market"
)

// An ongoing K-line's JSON read, a field looked at, and the record written again as its canonical text.
func ExampleDecodeOngoingKLine() {
	text := `{"index": 6, "date": 1767623760000, "open": 100.45, "high": 100.6, "low": 100.4, "close": 100.55,
"volume": 0.25, "asOf": 1767623790000}`
	k, err := market.DecodeOngoingKLine([]byte(text))
	if err != nil {
		fmt.Println(err)
		return
	}
	fmt.Println(k.High, k.High.Cmp(k.Close) > 0)
	canonical, _ := market.EncodeOngoingKLine(k)
	fmt.Print(canonical)
	// Output:
	// 100.6 true
	// {"asOf":1767623790000,"close":100.55,"date":1767623760000,"high":100.6,"index":6,"low":100.4,"open":100.45,"volume":0.25}
}
