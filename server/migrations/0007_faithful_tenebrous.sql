ALTER TABLE "friendship" ALTER COLUMN "status" SET DATA TYPE text;--> statement-breakpoint
ALTER TABLE "friendship" ALTER COLUMN "status" SET DEFAULT 'requested'::text;--> statement-breakpoint
ALTER TABLE "friendship" ADD COLUMN "ignored_at" timestamp with time zone;--> statement-breakpoint
-- Convert existing `declined` rows: a past decline becomes a silent ignore. The
-- edge returns to `requested` with ignored_at set, so it leaves the requestee's
-- incoming list for their Ignored surface (nothing is lost; re-requestable).
-- Must run while `status` is text — before the enum no longer has 'declined'.
UPDATE "friendship" SET "status" = 'requested', "ignored_at" = now() WHERE "status" = 'declined';--> statement-breakpoint
DROP TYPE "public"."friendship_status";--> statement-breakpoint
CREATE TYPE "public"."friendship_status" AS ENUM('requested', 'accepted');--> statement-breakpoint
ALTER TABLE "friendship" ALTER COLUMN "status" SET DEFAULT 'requested'::"public"."friendship_status";--> statement-breakpoint
ALTER TABLE "friendship" ALTER COLUMN "status" SET DATA TYPE "public"."friendship_status" USING "status"::"public"."friendship_status";
