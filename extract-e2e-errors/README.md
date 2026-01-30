# extract-e2e-errors.sh

Extract failed E2E tests from GitHub Actions runs.

## Usage

### Interactive Mode

Run without arguments to get prompted for each option:

```bash
./extract-e2e-errors.sh
```

You'll be guided through selecting:
1. **Run ID** - GitHub Actions run ID
2. **Attempt** - attempt number (leave empty for latest)
3. **Test Type** - `all`, `js-api`, `rest-api`, `soap-api`, `acceptance`, `mobile`
4. **Environment** - `all`, `cloud`, `on-premises`, `cloud-for-neco`
5. **Application** - `all`, `schedule`, `workflow`, `mail`, etc.

### Non-interactive Mode

Pass arguments directly:

```bash
./extract-e2e-errors.sh <RUN_ID> [TEST_TYPE] [APPLICATION] [ENVIRONMENT] [ATTEMPT]
```

| Arg | Values | Default |
|-----|--------|---------|
| RUN_ID | GitHub Actions run ID | required |
| TEST_TYPE | `all` `js-api` `rest-api` `soap-api` `acceptance` `mobile` | all |
| APPLICATION | `all` `schedule` `workflow` `mail` `message` `bulletin` `board` `cabinet` `report` `phone` `space` `timecard` `presence` `notification` `portal` | all |
| ENVIRONMENT | `all` `cloud` `on-premises` `cloud-for-neco` | all |
| ATTEMPT | attempt number (1, 2, 3...) | latest |

Use `all` or `""` to skip a filter.

## Examples

```bash
# Interactive mode
./extract-e2e-errors.sh

# All failures (latest attempt)
./extract-e2e-errors.sh 21502793220

# js-api only
./extract-e2e-errors.sh 21502793220 js-api

# js-api schedule app (all envs)
./extract-e2e-errors.sh 21502793220 js-api schedule

# js-api all apps, on-premises only
./extract-e2e-errors.sh 21502793220 js-api all on-premises

# Specific attempt (attempt 2)
./extract-e2e-errors.sh 21502793220 all all all 2

# js-api failures from attempt 1
./extract-e2e-errors.sh 21502793220 js-api all all 1
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
