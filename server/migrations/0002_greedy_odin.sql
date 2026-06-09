CREATE TYPE "public"."squad_role" AS ENUM('captain', 'member');--> statement-breakpoint
CREATE TABLE "squad" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"name" text NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "squad_membership" (
	"squad_id" uuid NOT NULL,
	"profile_id" uuid NOT NULL,
	"role" "squad_role" DEFAULT 'member' NOT NULL,
	CONSTRAINT "squad_membership_squad_id_profile_id_pk" PRIMARY KEY("squad_id","profile_id")
);
--> statement-breakpoint
ALTER TABLE "squad_membership" ADD CONSTRAINT "squad_membership_squad_id_squad_id_fk" FOREIGN KEY ("squad_id") REFERENCES "public"."squad"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "squad_membership" ADD CONSTRAINT "squad_membership_profile_id_profile_id_fk" FOREIGN KEY ("profile_id") REFERENCES "public"."profile"("id") ON DELETE cascade ON UPDATE no action;