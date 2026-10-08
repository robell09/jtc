# JTC v8.290 — 경량 v8.289 기반 사전신호 주문·추가진입

사용자가 첨부한 `Joon_Trade_Compass_v8_289_M3LightweightCsvParity.zip`을 기준으로 작성했습니다. 기존 경량 소스 위에 앞서 요청한 새 저점/고점 PRE 주문과 PRE/DIRECTION 추가진입을 이식했습니다. **버전만 바꾼 파일은 아닙니다.**

## 설치·전략테스터

1. `Joon_Trade_Compass_v8_290_M3LightweightTurnAdd` 폴더 전체를 MT5 데이터 폴더의 `MQL5/Experts/`에 넣습니다. 헤더 일부를 이전 버전 폴더에 섞지 마세요.
2. 첨부 `Indicators/Market`의 두 MQ5 파일을 `MQL5/Indicators/Market/`에 넣고 MetaEditor에서 먼저 컴파일합니다.
3. `Joon_Trade_Compass_v8_290.mq5`를 컴파일합니다. EX5는 포함하지 않습니다.
4. 전략테스터에서 **v8.290** EA, **GOLD · M3 · 실제 틱 기반 모든 틱**을 선택합니다.
5. `InpTurnTradeEnabled=true`, `InpTurnPreEnabled=true`, `InpTurnAddOnPre=true`, `InpTurnAddOnDirection=true`로 새 로직을 실행합니다. **추가진입을 테스트하려면 `InpDefaultAdditionalEntries`(MAX ADD)를 1 이상으로 변경하세요. 기본 0은 ADD OFF입니다.** 기존 lot·스프레드·손절 설정을 확인합니다.
6. `InpTesterAutoStart=true`는 테스터 AUTO 시작 설정입니다. 실시간 AUTO 기본값은 OFF입니다.
7. `InpTurnTradeEnabled=false`이면 첨부 v8.289의 기존 경량 WATCH/ACCEL/DIRECTION 주문 경로를 사용합니다. 새 PRE/DIRECTION은 이 경우 주문 권한이 없는 진단입니다. 이전 .set을 불러온 뒤 위 입력값을 확인하세요.

## 실행하는 주문

- 무포지션: 새 저점 LONG PRE는 BUY, 새 고점 SHORT PRE는 SELL.
- 같은 방향 보유: 새 PRE 또는 새 DIRECTION에 ADD. MAX ADD는 두 종류를 합친 cycle 누적 체결 횟수이며 한 확인 봉당 최대 한 번만 시도합니다. PRE가 우선합니다.
- 반대 PRE: 기존 EA 소유 포지션 청산. 모두의 최종 청산 거래가 처리되고 cycle 정리가 끝난 후 다음 틱에 반대 진입을 한 번 시도합니다. `InpTurnReverseOnOpposite=false`이면 청산만 합니다.
- DIRECTION은 같은 방향 ADD 전용입니다. 최초 진입·반대 청산에는 쓰지 않습니다. 가격/MACD buffer 7 진행, 이전 방향신호 고저점 종가 돌파, OFF→ON 재발생 규칙을 사용합니다. 방향의 기준은 기존 WATCH 대신 새 PRE가 잡습니다.
- 최초/추가진입을 실행한 진행봉, 청산·ADD 동기화 대기 중, OFF, 오래된 신호, MAX ADD 초과는 ADD하지 않습니다. 같은 봉의 실패를 다른 신호로 재시도하지 않습니다.
- 기존 lot·총 lot·스프레드·거래 권한·손절 안전 검사를 유지합니다. 기존 M3 기준처럼 ADD에 별도 수익 상태 필터를 요구하지 않으므로 손실 상태에서도 신호와 안전 조건이 맞으면 ADD할 수 있습니다.
- 퍼센트 broker SL은 유지하고 TP는 없습니다. 새 모드에서는 기존 WATCH/ACCEL 주문과 기존 Peak80/전략 청산 경로를 함께 실행하지 않습니다.

## 사전신호와 표시 시점

PRE는 이전 6봉 대비 극점, 다음 확정봉의 반등/하락, raw MACD·Final Wave·Delta의 변화, raw MACD 다이버전스, ATR 거리 0.15~1.25와 같은 방향 3봉 cooldown을 결합합니다. 진행 중 0번 봉은 읽지 않습니다. 극점 봉 이후 다음 M3 봉까지 확정되어야 계산할 수 있으며 회색 pivot 표시는 당시 진입 신호가 아닙니다.

녹색/빨간 화살표는 PRE, 파란/주황 화살표는 DIRECTION ADD 후보입니다. 실제 주문은 보유 방향과 제한·안전 검사에 따라 달라집니다.

## 경량 구조와 CSV

새 신호 계산은 StateEvaluation이 이미 확보한 배열을 사용하며 별도 CopyRates/CopyBuffer 경로를 추가하지 않았습니다. 새 주문 모드는 캐시의 M3 구조 관측과 확정봉 CSV를 유지하고 legacy RANGE/WatchSignal 계산·주문을 호출하지 않습니다. 기존 경량 경로는 비교용 옵션으로 그대로 남았습니다. **실제 MT5 속도 개선률은 측정하지 않았습니다.**

- EA / `ea_version`: `8.290`
- CSV / `csv_schema_version`: `8.290-LIGHTWEIGHT-TURN-ADD`
- 통합 CSV: 기존 610컬럼 + PRE 16 + DIRECTION 6 = **632컬럼**
- 실시간 메인 CSV: `Joon/JTC_v8.290_GOLD_YYYYMMDD_HHMMSS.csv`
- 테스터 메인 CSV: `Joon/Test/TEST_<run_id>_JTC_v8.290_GOLD_YYYYMMDD_HHMMSS.csv`

예: `TEST_20260701_000000_12345_D2982846829_4951_JTC_v8.290_GOLD_20260701_000000.csv`.

`order_signal_source=TURN_PRE` 또는 `DIRECTION`, `TURN-...` / `TURN-DIR-...` 이벤트 ID, `TURN PRE INITIAL` / `TURN ADD ... SOURCE=...` / `TURN PRE OPPOSITE EXIT` 사유로 새 주문을 확인하세요. 기존 WATCH/ACCEL/M3 구조 필드는 새 모드에서는 진단 정보입니다. 메인 CSV는 확정 M3 봉마다 `BAR/M3_CANONICAL` 행을 계속 기록합니다. 기존 별도 보조 CSV의 스키마 명칭은 해당 형식을 따릅니다.

## 검증과 한계

52개 주문 모의 시나리오를 통과했습니다. 기존 자료 14,639봉에서 PRE 74개와 DIRECTION 후보 308개를 재현했고 실제 MQL 코어/배열 adapter 실행 결과와 대조했습니다. CSV 파일명을 만드는 실제 함수의 실시간/테스터 조합, 버전·스키마·22개 추가 필드와 경량 분기 유지도 검사했습니다.

이 수치는 실제 주문 횟수·승률·수익이 아닙니다. **전체 MetaEditor 컴파일·MT5 전략테스터·MT5 속도 벤치마크는 이 환경에서 실행하지 못했습니다.** 기존 다중 청산 cycle PnL 집계 문제 전체를 수정한 버전도 아닙니다. 실제 결과는 broker position-history와 비용을 포함해 평가해야 합니다.

`tests/`에 검증 결과와 원본 v8.289 대비 diff가 있습니다. Python(pandas/numpy)과 C++17 g++에서 `tests/validate.py`, `tests/validate_orders.py`, `tests/validate_direction.py`, `tests/validate_lightweight.py`로 재현합니다. `analysis/`는 이 검증에 필요한 기존 CSV의 축약 자료입니다.
