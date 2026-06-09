CREATE TYPE "public"."community_role" AS ENUM('leader', 'follower');--> statement-breakpoint
CREATE TABLE "community" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"name" text NOT NULL,
	"tagline" text,
	"icon" text,
	"color" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "community_event" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"community_id" uuid NOT NULL,
	"title" text NOT NULL,
	"activity_type_id" uuid,
	"time" text,
	"recurrence" text,
	"location" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "community_event_rsvp" (
	"event_id" uuid NOT NULL,
	"profile_id" uuid NOT NULL,
	"going" boolean DEFAULT false NOT NULL,
	"public" boolean DEFAULT false NOT NULL,
	CONSTRAINT "community_event_rsvp_event_id_profile_id_pk" PRIMARY KEY("event_id","profile_id")
);
--> statement-breakpoint
CREATE TABLE "community_membership" (
	"community_id" uuid NOT NULL,
	"profile_id" uuid NOT NULL,
	"role" "community_role" DEFAULT 'follower' NOT NULL,
	CONSTRAINT "community_membership_community_id_profile_id_pk" PRIMARY KEY("community_id","profile_id")
);
--> statement-breakpoint
ALTER TABLE "community_event" ADD CONSTRAINT "community_event_community_id_community_id_fk" FOREIGN KEY ("community_id") REFERENCES "public"."community"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "community_event" ADD CONSTRAINT "community_event_activity_type_id_topic_id_fk" FOREIGN KEY ("activity_type_id") REFERENCES "public"."topic"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "community_event_rsvp" ADD CONSTRAINT "community_event_rsvp_event_id_community_event_id_fk" FOREIGN KEY ("event_id") REFERENCES "public"."community_event"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "community_event_rsvp" ADD CONSTRAINT "community_event_rsvp_profile_id_profile_id_fk" FOREIGN KEY ("profile_id") REFERENCES "public"."profile"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "community_membership" ADD CONSTRAINT "community_membership_community_id_community_id_fk" FOREIGN KEY ("community_id") REFERENCES "public"."community"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "community_membership" ADD CONSTRAINT "community_membership_profile_id_profile_id_fk" FOREIGN KEY ("profile_id") REFERENCES "public"."profile"("id") ON DELETE cascade ON UPDATE no action;