# JTC v8.286 — M3 저점·고점 사전신호 주문 버전

이 패키지는 **차트 확인용 단독 인디케이터**와 **동일 계산 코어를 사용하는 EA 통합 소스**를 포함합니다. 원본 MACD·Delta 지표 소스도 포함했습니다. EX5는 포함하지 않았고, MT5 전체 컴파일·백테스트는 이 환경에서 실행하지 못했습니다.

## 먼저 실행할 순서

1. MT5 → 파일 → 데이터 폴더 열기. ZIP의 `MQL5` 폴더 내부 구조에 맞춰 파일을 넣습니다. 이전 EA 폴더는 보존하고 일부 헤더만 섞어 덮어쓰지 마세요.
2. MetaEditor에서 아래 두 지표를 먼저 컴파일합니다.
   - `MQL5/Indicators/Market/Joon_MACD_v2_05_OPT_VALIDATION.mq5`
   - `MQL5/Indicators/Market/Joon_delta_volume_v1_01_OPT_VALIDATION.mq5`
3. **차트 신호만 확인할 때:** `MQL5/Indicators/JTC_TurnPre/JTC_M3_TurnPre_v8_284.mq5`를 컴파일하고 GOLD 3분봉 차트에 적용합니다. 자동매매 권한 없이 사용할 수 있습니다.
4. **EA CSV까지 확인할 때:** `MQL5/Experts/Joon_Trade_Compass_v8_286_TurnAdd/Joon_Trade_Compass_v8_286.mq5`를 컴파일하고 기존 설정과 동일 조건으로 테스트합니다.
5. 단독 지표와 EA를 동시에 적용하면 같은 신호가 겹쳐 보일 수 있습니다. 먼저 하나씩 확인하세요. 독립 지표는 기본 최근 3,000봉, EA의 warmup 차트 표시는 기본 2,000봉 범위이므로 최초 역사 경계의 cooldown 상태 차이는 고려하세요.
6. 새 주문 모드의 기본값은 `InpTurnTradeEnabled=true`, `InpTurnReverseOnOpposite=true`입니다. 전략테스터 Period를 M3로 선택하세요. `InpTesterAutoStart=true`이면 테스터에서 AUTO가 시작됩니다. 실시간 차트에서는 AUTO 스위치를 직접 켜야 합니다. **추가진입을 테스트하려면 `InpDefaultAdditionalEntries`(MAX ADD)를 1 이상으로 설정하세요. 기본값 0은 OFF입니다.** `InpTurnAddOnPre=true`, `InpTurnAddOnDirection=true`이면 두 종류의 신호를 모두 사용합니다.
7. 새 모드는 이전 WATCH/ACCEL·구조 ADD·기존 전략 청산 경로를 실행하지 않습니다. DIRECTION의 가격/MACD 진행 조건을 새 사전신호 소유 방향에 연결한 별도 계산 경로를 사용합니다. 손절은 기존 메뉴의 퍼센트 SL을 사용하고 TP는 설정하지 않습니다. INITIAL과 ADD 포지션은 반대 TURN PRE 또는 broker SL/수동·안전 청산까지 유지합니다. 기존 Peak80 수익잠금도 새 모드에서는 실행하지 않습니다.
8. `InpTurnTradeEnabled=false`이면 v8.284의 기존 주문 경로로 돌아갑니다. 이 경우 TURN PRE는 다시 표시·기록용입니다. 단독 `JTC_M3_TurnPre_v8_284.mq5`는 같은 계산 코어를 사용하며 주문하지 않습니다.

## 차트 읽는 법과 확정 시점

- 녹색 위 화살표: 저점 LONG 사전신호.
- 빨간 아래 화살표: 고점 SHORT 사전신호.
- 회색 점: 신호가 참조한 이전 봉의 저점·고점. **그 봉 당시에는 아직 모르는 위치 표시이며, 다음 3분봉이 확정된 후에만 추가됩니다.** 진입 신호가 아닙니다.
- 화살표는 확인 봉에 표시되지만 계산이 가능해지는 시점은 그 봉의 종가 확정 이후입니다. 진행 중 0번 봉에는 화살표를 만들지 않습니다. EA 화살표 tooltip에 pivot/확인 봉/최초 사용 가능 시간을 표시합니다.
- 예: 저점 봉이 10:00~10:03이고 다음 확인 봉이 10:03~10:06이면 신호는 **10:06 이후 첫 계산**에서 알 수 있습니다. 10:00에 이미 알고 있었던 것처럼 소급 주문하지 않습니다.
- 단독 지표 buffer 0=LONG 확인 화살표, 1=SHORT 확인 화살표, 2/3=나중에 확인된 pivot 주석입니다. 자동매매에서 읽는다면 **buffer 0/1의 확정봉 shift≥1만** 읽고, pivot 주석 buffer 2/3을 당시 진입 신호로 쓰지 마세요.

## 구현한 기본 조건

현재 확정봉을 C, 그 직전 봉을 P, P보다 이전 6봉의 최저/최고 봉을 E로 정의합니다. ATR은 C까지의 14봉 TR 단순 평균입니다.

### LONG

1. P.low가 P 이전 6봉의 최저 low 이하입니다.
2. C.low>P.low이고 C.close>P.close입니다. P보다 더 낮은 저점이 나오면 취소합니다.
3. `(C.close−P.low)/ATR14`가 0.15~1.25입니다. 너무 작은 반등과 늦은 추격을 제외합니다.
4. `RawMACD[C]−RawMACD[P] > 0.01×ATR14`.
5. `UnscaledFinalWave[C]−UnscaledFinalWave[P] > 0.01×ATR14`.
6. RawDelta[C]>0이고 EMA_Delta[C]>EMA_Delta[P]입니다. 비교에 필요한 volume은 양수여야 합니다.
7. 기본 다이버전스: P의 가격은 E의 low 이하인데 `RawMACD[P]−RawMACD[E] > 0.01×ATR14`입니다.
8. 같은 방향 신호는 최소 3개 M3 봉 간격으로 제한합니다.

### SHORT

위 규칙을 고점·가격 하락·MACD/Final Wave 하락·음수 Delta/EMA 감소로 대칭 적용합니다. P의 가격 high는 이전 high 이상인데 Raw MACD는 이전 고점 봉보다 낮아야 합니다.

동률 극점은 가장 최근 봉을 참조합니다. 지표 EMPTY_VALUE/비정상 수치, volume 부족, 필요한 최근 14봉의 180초 연속성 단절은 신호를 만들지 않습니다. 과거 방향 신호, 현재 진행봉, 이후 수익은 계산 입력으로 사용하지 않습니다. Raw MACD와 Final Wave는 같은 가격 정보를 공유하므로 ‘3점’은 조건 충족 수이고 독립적인 신뢰확률이 아닙니다.

MACD zero-cross를 기다리지 않습니다. 가격 극점 부근에서 힘의 변화와 압력 회복을 먼저 관찰하는 별도 사전신호입니다. 이전 6봉(18분) 범위의 국소 극점을 선별하며, 하루 전체 최저·최고나 모든 스윙을 찾는 프로그램이 아닙니다.

## 설정

- `InpTurnAddOnPre=true`: 같은 방향 새 PRE에 추가진입.
- `InpTurnAddOnDirection=true`: 같은 방향 새 DIRECTION에 추가진입.
- `InpDefaultAdditionalEntries=0`: 기본 OFF. 테스트할 MAX ADD 횟수로 변경해야 주문됩니다.

- `InpTurnTradeEnabled=true`: TURN PRE 전용 주문 모드.
- `InpTurnReverseOnOpposite=true`: 반대 신호 청산 후 체결 확인 시 반대 진입. false이면 반대 신호로 청산만 합니다.
- `InpTurnPreEnabled=true` (EA): 새 차트/CSV/주문 공통 계산. 새 주문 모드에서 false는 초기화 오류입니다.
- `InpTurnRequireDivergence=true`: 기본 선별형. false이면 가격+현재 MACD/Final Wave/Delta 확인만 사용하므로 신호가 늘어납니다.
- `InpTurnLeftBars=6` (2~12): 극점 비교 범위.
- `InpTurnMinReboundATR=0.15`, `InpTurnMaxDistanceATR=1.25`: 극점 대비 현재 거리.
- `InpTurnMomentumDeadzoneATR=0.01`: MACD/Final Wave·다이버전스 최소 변화.
- `InpTurnSameSideCooldownBars=3`: 같은 방향 반복 제한.
- `InpTurnShowPivotAnchors=true`: 회색 극점 위치 주석. 신호 시점을 혼동한다면 false로 끄세요.

숫자를 최적값이라고 주장하지 않습니다. 기존 자료에서 몇 가지 확인 조건을 비교한 탐색 설정이며, 별도 테스트 기간으로 평가해야 합니다.

## CSV 및 검증

EA CSV version은 `8.286-TURNPRE-DIRECTION-ADD`, **634컬럼**입니다. 새 TURN PRE 관련 16개 필드:

`turn_pre_enabled`, `turn_pre_data_valid`, `turn_pre_signal`, `turn_pre_side`, `turn_pre_confirm_bar`, `turn_pre_available_time`, `turn_pre_pivot_time`, `turn_pre_pivot_price`, `turn_pre_score`, `turn_pre_distance_r`, `turn_pre_long_divergence_r`, `turn_pre_short_divergence_r`, `turn_pre_opposite`, `turn_pre_reason`, `turn_pre_require_divergence`, `turn_pre_atr14`.

`turn_pre_available_time`은 확인 봉의 이론상 종료시각입니다. 실제 계산·체결은 다음 tick에서 더 늦을 수 있습니다. `turn_pre_opposite`는 계산 직전 확정된 기존 ASSIST 방향의 반대인지 보여줍니다. 이 필드는 표시용이며 주문 반대 여부는 실제 EA 소유 포지션 방향과 비교합니다. 한 확정봉의 snapshot이 여러 이벤트 행에 반복되므로 **confirm_bar+side로 중복 제거**해야 합니다.

제공 CSV의 14,639봉에서 기본 조건은 LONG 43, SHORT 31, 총 74개를 만들었습니다. 유효한 5봉 후 방향 평가 72개 중 42개가 같은 방향(58.3%)이었고 평균 +0.3456 ATR이었습니다. ±1ATR first-touch 5봉 평가에서는 target 31/stop 26/timeout 15였습니다. 5봉 동안 pivot 가격이 유지된 것은 72개 중 43개였습니다. 즉 이미 확정된 작은 극점이 이후 더 큰 추세에서 다시 깨질 수 있습니다.

이 수치는 **체결·비용을 반영하지 않은 가격 평가**이며 실제 거래 승률·순수익이 아닙니다. 7월/8월은 탐색에 사용한 자료이지 독립 holdout이 아닙니다. 신호가 엄격해 모든 저점·고점을 포착하지 않습니다. `InpTurnRequireDivergence=false` 비교에서는 192개 신호, 유효 189개 중 5봉 방향 일치율 51.3%였습니다.

첨부 지표의 default 계산을 CSV와 대조했습니다. 최초 500봉 seed 영향을 제외한 14,139봉에서 Delta 원시값/EMA, Raw Price MACD의 오차는 CSV의 8자리 반올림 범위였습니다. EA와 단독 지표는 표시용 자동 스케일 버퍼가 아닌 **MACD buffer 5/6, Delta buffer 2/3/4**를 사용합니다. 사용자에게 받은 두 지표 소스는 그대로 포함했습니다. Delta는 실제 aggressor trade delta가 아니라 봉 형태×volume의 추정치입니다.

새 MQL 코어·배열 adapter의 실제 함수 본문을 C++ 호환 harness로 실행해 전체 신호 시퀀스와 Python 분석의 일치를 확인했습니다. 0번 봉 금지, 미래값 변경, gap/invalid/zero-volume, 방향 대칭, 다이버전스 옵션과 cooldown 경계도 검사했습니다. **이 검증은 전체 MQL5 컴파일·MT5 버퍼 업데이트·차트 실행 검증을 대체하지 않습니다.** MetaEditor 오류가 있으면 전체 로그를 제공해 주세요.

## 추가진입용 방향신호

기존 SIMPLE_DIRECTION의 핵심 조건(가격 진행 + MACD buffer 7 진행 + 이전 방향신호 극점 돌파 + OFF→ON 재발생)을 유지합니다. 이전 WATCH가 만든 방향 소유권은 이번 모드에서 **새 TURN PRE가 만든 방향 소유권**으로 바꿨습니다. 따라서 기존 WATCH 기반 방향신호와 후보 시퀀스가 완전히 같지는 않습니다. 기존 전체 SignalEngine을 다시 실행해 옛 주문 권한을 섞지 않습니다.

- LONG: 새 LONG PRE가 기준 방향을 만든 뒤의 확정봉에서 close가 직전 close보다 높고 high도 더 높으며, MACD base(buffer 7)가 증가합니다. 해당 구간에 이전 LONG 방향신호가 있다면 close가 그 신호 봉의 high도 넘어야 합니다.
- SHORT: close·low·MACD base 감소, 이전 SHORT 방향신호 봉의 low 아래 종가로 대칭 적용합니다.
- 정렬 조건이 연속 TRUE이면 한 번만 발생합니다. FALSE가 된 뒤 다시 TRUE가 될 때 재발생합니다.
- 새 PRE가 나온 봉에서는 방향신호를 만들지 않습니다. 새 PRE가 구간 기준을 다시 설정합니다.
- 진행 중 0번 봉은 읽지 않습니다. 확인 봉 종료 후 다음 틱에서만 주문할 수 있습니다. 데이터 단절/비정상 MACD이면 방향 소유권과 active 상태를 지우고 새 PRE를 기다립니다.
- 파란/주황 방향 화살표는 **추가진입 후보**입니다. 실제 보유 포지션 방향과 일치해야 하며 무포지션의 최초 진입이나 반대 청산에는 사용하지 않습니다. 기존 녹색/빨간 PRE 화살표는 그대로 유지합니다.

`InpTurnAddOnPre`와 `InpTurnAddOnDirection`으로 각각 끌 수 있습니다. 기존 `MAX ADD`를 0으로 두면 둘 다 계산·기록되지만 추가진입 주문은 없습니다. 횟수 제한은 각 종류별 제한이 아닌 **두 종류를 합친 cycle 누적 체결 횟수**입니다. lot은 기존 메뉴 lot이며 `InpMaximumTotalLots`와 주문 안전 검사도 공유합니다.

최초 진입/직전 추가진입이 실행된 진행봉에서는 ADD하지 않습니다. 청산 또는 ADD 체결 동기화가 대기 중이면 차단하고, 같은 확인 봉에서 실패한 ADD를 다른 신호 종류로 재시도하지 않습니다. 기존 M3 ADD 기준처럼 손익이 양수라는 별도 전략 필터는 적용하지 않으므로 보유 포지션 손실 상태에서도 신호와 안전 조건이 맞으면 ADD할 수 있습니다. 청산·손절 후에는 새로운 PRE로 최초 진입을 시작해야 합니다.

기존 CSV의 14,639봉에서 PRE는 74개 그대로이며 새 방향신호 계산은 308개(LONG 184/SHORT 124) 후보였습니다. **보유 상태·MAX ADD·체결 조건을 반영한 실제 ADD 횟수나 수익이 아닙니다.** 실제 MACD buffer 7 자료를 추가해 전체 방향신호 시퀀스의 독립 계산과 MQL core/adapter 실행 결과를 대조했고, 모든 봉의 0번 봉 값을 바꾸어도 결과가 같음을 확인했습니다.

CSV에는 기존 16개 PRE 필드 외에 `turn_direction_valid`, `turn_direction_signal`, `turn_direction_side`, `turn_direction_bar`, `turn_direction_owner_side`, `turn_direction_reason` 6개가 추가돼 총 634컬럼입니다. ADD source는 `TURN_PRE` 또는 `DIRECTION`, 방향 이벤트 ID는 `TURN-DIR-확인봉시각-L/S`, ADD 사유는 `TURN ADD... SOURCE=...`입니다.

## 새 주문 로직 및 남은 한계

- 무포지션 + LONG 사전신호: 시장가 BUY. SHORT: 시장가 SELL.
- 같은 방향 포지션 보유 + 새 사전신호: `InpTurnAddOnPre=true`일 때 ADD 후보. 새 방향신호: `InpTurnAddOnDirection=true`일 때 ADD 후보. 두 종류가 겹쳐도 같은 확인 봉에는 한 번만 시도하고 PRE를 우선합니다.
- 반대 방향 보유: 이 심볼+Magic의 기존 포지션을 청산. 다른 EA/수동 포지션은 청산하지 않습니다.
- 반대 진입: 모든 기존 포지션 식별자의 최종 청산 거래가 OnTradeTransaction에서 처리되고 기존 cycle 원장이 정리된 후, **다음 틱**에 딱 한 번 시도합니다. 부분 청산, 청산 실패, 체결 콜백 미확인은 반대 진입을 허용하지 않습니다.
- LONG ONLY/SHORT ONLY는 신규 진입에 적용합니다. 반대 신호의 기존 포지션 청산은 허용하되 금지 방향의 재진입은 하지 않습니다.
- 현재 진행봉이 바뀌면 대기 반대 진입은 만료됩니다. AUTO/SYSTEM OFF에서도 대기를 취소합니다. OFF 때 관측한 신호를 나중에 ON으로 바꿔 재사용하지 않습니다.
- 신규 주문 직전 Ask/Bid와 pivot의 거리가 기존 0.15~1.25 ATR 범위를 벗어나면 주문을 차단합니다. 차트 신호가 있어도 스프레드·슬리피지·지연·거래 권한·손절 설치 가능성 때문에 주문하지 않을 수 있습니다.
- 주문 실패는 같은 신호로 재시도하지 않습니다. 청산 실패 시 남은 포지션에는 broker SL이 유지되며 다음 새 반대 신호/수동 청산을 기다립니다.
- 기존 lot, 최대 lot, 스프레드, 거래 권한, 매매 가능 방향, 손절 설치 안전 검사를 유지했습니다. 기존 전략의 신호 품질 조건을 TURN 주문에 다시 적용하지 않습니다.
- 최초 부착의 과거 replay는 주문하지 않습니다. v8.286에서 M3+ASSIST warmup의 TURN pulse도 명시적으로 지웠습니다.

CSV 634컬럼을 사용하며 `order_signal_source=TURN_PRE`와 `TURN-확인봉시각-L/S` 이벤트 ID, `TURN_ORDER` audit, `TURN PRE INITIAL/OPPOSITE EXIT` 사유로 신규 주문을 식별합니다. 기존 WATCH/ACCEL 상태 필드는 진단 정보이며 새 모드의 주문 근거가 아닙니다. 테스터 결과는 실제 체결된 ENTRY/CLOSE/SL 및 broker position PnL로 평가하세요.

기존 74개 사전신호의 58.3% 방향 일치율은 **v8.286 거래 승률이나 수익이 아닙니다**. 이 버전의 ADD·SL·반대 청산·시장가 비용을 포함한 성과는 MT5 전략테스터에서 새로 측정해야 합니다. 앞으로 발생할 극점은 알 수 없으므로 저점/고점 봉 당시 진입하지 않습니다.

청산 콜백 전에 새 cycle을 만들지 않도록 새 반대 진입 경로를 분리했지만, 이전부터 발견한 다중 청산 cycle 집계 문제 전체를 수정한 버전은 아닙니다. broker position-history 합계로 성과를 맞춰야 합니다. 기존 CSV 마지막 청산 기록 불일치도 원본 데이터의 한계로 남아 있습니다.

52개 주문 시나리오에서 실제 MQL 주문 router 본문을 C++ 모의 터미널로 실행해 양방향 진입·중복 방지·사전신호/방향신호 ADD·중복 제한·용량 제한·청산 확인 대기·다중 포지션 확인·부분/실패 청산·OFF/만료·방향 제한·가격 이탈·기존 lifecycle 대기를 검사했습니다. broker 실행, 전체 MQL5 타입 검사와 MT5 전략테스터 실행을 대체하지 않습니다. **EX5 없음 / 전체 MT5 컴파일·백테스트 미실행**입니다.

## 재현 자료

`analysis/`에 원본 CSV에서 추출한 필요한 10개 컬럼의 14,639봉, 신호 목록, 비교 통계와 차트 예제를 포함했습니다. 전체 원본 214MB CSV는 중복 포함하지 않았습니다. Python/pandas/numpy와 C++17 g++ 환경에서 `tests/validate.py`를 실행하면 동일 코어를 재검사하고 `tests/validate_orders.py`로 새 주문 router, `tests/validate_direction.py`로 방향신호 core와 adapter를 재검사할 수 있습니다. 연구 코드 실행 순서와 환경은 `analysis/REPRODUCE.md`를 참고하세요.
