CREATE TYPE "public"."want_kind" AS ENUM('one_shot', 'ongoing');--> statement-breakpoint
CREATE TABLE "want" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"owner_id" uuid NOT NULL,
	"activity_type_id" uuid NOT NULL,
	"title" text,
	"location" text,
	"notes" text,
	"kind" "want_kind" DEFAULT 'one_shot' NOT NULL,
	"archived_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "want_invite" (
	"want_id" uuid NOT NULL,
	"profile_id" uuid NOT NULL,
	"response" "response_value",
	"ignored_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "want_invite_want_id_profile_id_pk" PRIMARY KEY("want_id","profile_id")
);
--> statement-breakpoint
ALTER TABLE "activity" ADD COLUMN "from_want_id" uuid;--> statement-breakpoint
ALTER TABLE "want" ADD CONSTRAINT "want_owner_id_profile_id_fk" FOREIGN KEY ("owner_id") REFERENCES "public"."profile"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "want" ADD CONSTRAINT "want_activity_type_id_topic_id_fk" FOREIGN KEY ("activity_type_id") REFERENCES "public"."topic"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "want_invite" ADD CONSTRAINT "want_invite_want_id_want_id_fk" FOREIGN KEY ("want_id") REFERENCES "public"."want"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "want_invite" ADD CONSTRAINT "want_invite_profile_id_profile_id_fk" FOREIGN KEY ("profile_id") REFERENCES "public"."profile"("id") ON DELETE cascade ON UPDATE no action;