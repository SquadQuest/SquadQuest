CREATE TYPE "public"."activity_scope" AS ENUM('friends', 'squad');--> statement-breakpoint
CREATE TYPE "public"."activity_state" AS ENUM('idea', 'confirmed');--> statement-breakpoint
CREATE TYPE "public"."audience_kind" AS ENUM('all_friends', 'people');--> statement-breakpoint
CREATE TYPE "public"."option_kind" AS ENUM('time', 'location');--> statement-breakpoint
CREATE TYPE "public"."response_value" AS ENUM('in', 'interested', 'next_time');--> statement-breakpoint
CREATE TABLE "activity" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"captain_id" uuid NOT NULL,
	"activity_type_id" uuid NOT NULL,
	"state" "activity_state" DEFAULT 'idea' NOT NULL,
	"scope" "activity_scope" DEFAULT 'friends' NOT NULL,
	"squad_id" uuid,
	"audience_kind" "audience_kind" DEFAULT 'all_friends' NOT NULL,
	"allow_suggestions" boolean DEFAULT false NOT NULL,
	"confirmed_time_option_id" uuid,
	"confirmed_location_option_id" uuid,
	"community_event_id" uuid,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"confirmed_at" timestamp with time zone
);
--> statement-breakpoint
CREATE TABLE "activity_audience" (
	"activity_id" uuid NOT NULL,
	"profile_id" uuid NOT NULL,
	CONSTRAINT "activity_audience_activity_id_profile_id_pk" PRIMARY KEY("activity_id","profile_id")
);
--> statement-breakpoint
CREATE TABLE "activity_option" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"activity_id" uuid NOT NULL,
	"kind" "option_kind" NOT NULL,
	"label" text NOT NULL,
	"created_by" uuid NOT NULL
);
--> statement-breakpoint
CREATE TABLE "option_vote" (
	"option_id" uuid NOT NULL,
	"profile_id" uuid NOT NULL,
	CONSTRAINT "option_vote_option_id_profile_id_pk" PRIMARY KEY("option_id","profile_id")
);
--> statement-breakpoint
CREATE TABLE "response" (
	"activity_id" uuid NOT NULL,
	"profile_id" uuid NOT NULL,
	"value" "response_value" NOT NULL,
	CONSTRAINT "response_activity_id_profile_id_pk" PRIMARY KEY("activity_id","profile_id")
);
--> statement-breakpoint
ALTER TABLE "activity" ADD CONSTRAINT "activity_captain_id_profile_id_fk" FOREIGN KEY ("captain_id") REFERENCES "public"."profile"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "activity" ADD CONSTRAINT "activity_activity_type_id_topic_id_fk" FOREIGN KEY ("activity_type_id") REFERENCES "public"."topic"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "activity_audience" ADD CONSTRAINT "activity_audience_activity_id_activity_id_fk" FOREIGN KEY ("activity_id") REFERENCES "public"."activity"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "activity_audience" ADD CONSTRAINT "activity_audience_profile_id_profile_id_fk" FOREIGN KEY ("profile_id") REFERENCES "public"."profile"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "activity_option" ADD CONSTRAINT "activity_option_activity_id_activity_id_fk" FOREIGN KEY ("activity_id") REFERENCES "public"."activity"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "activity_option" ADD CONSTRAINT "activity_option_created_by_profile_id_fk" FOREIGN KEY ("created_by") REFERENCES "public"."profile"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "option_vote" ADD CONSTRAINT "option_vote_option_id_activity_option_id_fk" FOREIGN KEY ("option_id") REFERENCES "public"."activity_option"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "option_vote" ADD CONSTRAINT "option_vote_profile_id_profile_id_fk" FOREIGN KEY ("profile_id") REFERENCES "public"."profile"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "response" ADD CONSTRAINT "response_activity_id_activity_id_fk" FOREIGN KEY ("activity_id") REFERENCES "public"."activity"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "response" ADD CONSTRAINT "response_profile_id_profile_id_fk" FOREIGN KEY ("profile_id") REFERENCES "public"."profile"("id") ON DELETE cascade ON UPDATE no action;