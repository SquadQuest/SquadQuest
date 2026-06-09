CREATE TYPE "public"."friendship_status" AS ENUM('requested', 'accepted', 'declined');--> statement-breakpoint
CREATE TABLE "friendship" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"requester" uuid NOT NULL,
	"requestee" uuid NOT NULL,
	"status" "friendship_status" DEFAULT 'requested' NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "friendship_pair" UNIQUE("requester","requestee")
);
--> statement-breakpoint
CREATE TABLE "profile" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"phone" text NOT NULL,
	"first_name" text,
	"last_name" text,
	"photo" text,
	"claimed_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "profile_phone_unique" UNIQUE("phone")
);
--> statement-breakpoint
CREATE TABLE "topic" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"noun" text NOT NULL,
	"verb" text NOT NULL,
	"label" text NOT NULL
);
--> statement-breakpoint
CREATE TABLE "topic_subscription" (
	"topic_id" uuid NOT NULL,
	"profile_id" uuid NOT NULL,
	CONSTRAINT "topic_subscription_topic_id_profile_id_pk" PRIMARY KEY("topic_id","profile_id")
);
--> statement-breakpoint
CREATE TABLE "otp_code" (
	"phone" text PRIMARY KEY NOT NULL,
	"code_hash" text NOT NULL,
	"expires_at" timestamp with time zone NOT NULL,
	"attempts" integer DEFAULT 0 NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "refresh_token" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"profile_id" uuid NOT NULL,
	"token_hash" text NOT NULL,
	"expires_at" timestamp with time zone NOT NULL,
	"revoked_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "refresh_token_token_hash_unique" UNIQUE("token_hash")
);
--> statement-breakpoint
ALTER TABLE "friendship" ADD CONSTRAINT "friendship_requester_profile_id_fk" FOREIGN KEY ("requester") REFERENCES "public"."profile"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "friendship" ADD CONSTRAINT "friendship_requestee_profile_id_fk" FOREIGN KEY ("requestee") REFERENCES "public"."profile"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "topic_subscription" ADD CONSTRAINT "topic_subscription_topic_id_topic_id_fk" FOREIGN KEY ("topic_id") REFERENCES "public"."topic"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "topic_subscription" ADD CONSTRAINT "topic_subscription_profile_id_profile_id_fk" FOREIGN KEY ("profile_id") REFERENCES "public"."profile"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "refresh_token" ADD CONSTRAINT "refresh_token_profile_id_profile_id_fk" FOREIGN KEY ("profile_id") REFERENCES "public"."profile"("id") ON DELETE cascade ON UPDATE no action;