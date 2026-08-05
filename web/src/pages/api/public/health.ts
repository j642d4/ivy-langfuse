import { VERSION } from "@/src/constants";
import { cors, runMiddleware } from "@/src/features/public-api/server/cors";
import { clickHouseRouteForRequest } from "@/src/features/public-api/server/clickHouseRequestTags";
import { runHealthCheck } from "@/src/features/public-api/server/health-service";
import {
  contextWithLangfuseProps,
  logger,
  traceException,
} from "@langfuse/shared/src/server";
import * as opentelemetry from "@opentelemetry/api";
import { type NextApiRequest, type NextApiResponse } from "next";

export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse,
) {
  try {
    await runMiddleware(req, res, cors);
    // telemetry() is deliberately not called here: it opens a Postgres
    // transaction (LOCK TABLE cron_jobs ... SHARE ROW EXCLUSIVE MODE) and, on a
    // fresh install with no cron_jobs row yet, runs six sequential ClickHouse
    // aggregate queries inside that same transaction before ever reaching the
    // PostHog capture() call. TELEMETRY_ENABLED=false doesn't prevent this —
    // telemetry()'s early-return guard is `TELEMETRY_ENABLED === "false" &&
    // LANGFUSE_EE_LICENSE_KEY === undefined`, and LANGFUSE_EE_LICENSE_KEY
    // resolves to "" (not literal undefined) via the env schema default even
    // when unset, so that guard is unreachable for self-hosted deployments
    // with no EE license. Calling this from the health-check hot path (hit
    // every 15s by ECS) held the table lock open indefinitely and hung the
    // process — no crash, no error, health check never responds.
    const ctx = contextWithLangfuseProps({
      headers: req.headers,
      clickhouse: {
        surface: "publicapi",
        route: clickHouseRouteForRequest(req),
      },
    });
    const result = await opentelemetry.context.with(ctx, () =>
      runHealthCheck({
        failIfNoRecentEvents: req.query.failIfNoRecentEvents === "true",
        failIfDatabaseUnavailable:
          req.query.failIfDatabaseUnavailable === "true",
      }),
    );

    return res.status(result.isHealthy ? 200 : 503).json({
      status: result.status,
      version: result.version,
    });
  } catch (e) {
    traceException(e);
    logger.error("Health check failed", e);
    return res.status(503).json({
      status: "Health check failed",
      version: VERSION.replace("v", ""),
    });
  }
}
