CREATE TYPE "public"."topic_kind" AS ENUM('official', 'community');--> statement-breakpoint
ALTER TABLE "topic" ADD COLUMN "kind" "topic_kind" DEFAULT 'official' NOT NULL;