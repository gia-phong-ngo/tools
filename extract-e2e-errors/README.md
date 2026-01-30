# main.sh

Extract failed E2E tests from GitHub Actions runs.

## Usage

### Interactive Mode

Run without arguments to get prompted for each option:

```bash
./main.sh
```

You'll be guided through selecting:
1. **Run ID** - GitHub Actions run ID
2. **Attempt** - attempt number (leave empty for latest)
3. **Test Type** - `all`, `js-api`, `rest-api`, `soap-api`, `acceptance`, `mobile`
4. **Environment** - `all`, `cloud`, `on-premises`, `cloud-for-neco`
5. **Application** - `all`, `schedule`, `workflow`, `mail`, etc., `others`

### Non-interactive Mode

Pass arguments directly:

```bash
./main.sh <RUN_ID> [ATTEMPT] [TEST_TYPE] [APPLICATION] [ENVIRONMENT]
```

| Arg | Values | Default |
|-----|--------|---------|
| RUN_ID | GitHub Actions run ID | required |
| ATTEMPT | attempt number (1, 2, 3...) | latest |
| TEST_TYPE | `all` `js-api` `rest-api` `soap-api` `acceptance` `mobile` | all |
| APPLICATION | `all` `schedule` `workflow` `mail` `message` `bulletin` `board` `cabinet` `report` `phone` `space` `timecard` `presence` `notification` `portal` `others` | all |
| ENVIRONMENT | `all` `cloud` `on-premises` `cloud-for-neco` | all |

Use `all` or `""` to skip a filter.

## Examples

```bash
# Interactive mode
./main.sh

# All failures (latest attempt)
./main.sh 21502793220

# All failures from attempt 2
./main.sh 21502793220 2

# js-api from attempt 2
./main.sh 21502793220 2 js-api

# js-api from latest attempt
./main.sh 21502793220 "" js-api

# js-api schedule from attempt 1
./main.sh 21502793220 1 js-api schedule

# js-api on-premises from attempt 2
./main.sh 21502793220 2 js-api all on-premises
```

## Output

```
e2e-errors-<RUN_ID>[-attempt<N>]/
  summary.txt   # Full report with all details
  logs/         # Raw job logs
```

Output format in summary.txt:
```
CONTAINER                    TEST_PATH
on-premises/js-api(0)        schedule/js-api/garoon.schedule.event.get/.../test.spec.js
cloud/js-api(0)              mail/js-api/mail.mail.create.show/.../test.spec.js
```
