import {
    createAnonSupabaseClient,
    createServiceRoleSupabaseClient,
    getSupabaseUser,
} from "../_shared/supabase.ts";
import {
    assertPost,
    getRequiredJsonParameters,
    HttpError,
} from "../_shared/http.ts";

Deno.serve(async (request) => {
    try {
        // process request
        assertPost(request);
        const { instance_id: instanceId, status } = await getRequiredJsonParameters(request, [
            "instance_id",
            "status"
        ]);

        // connect to Supabase
        const serviceRoleSupabase = createServiceRoleSupabaseClient();
        const anonSupabase = createAnonSupabaseClient(request);

        // get requesting user
        const currentUser = await getSupabaseUser(anonSupabase, request);
        if (!currentUser) {
            throw new HttpError(
                "Authorized user not found",
                403,
                "authorized-user-not-found",
            );
        }

        // get event
        const { data: event, error: eventError } =
            await serviceRoleSupabase.from(
                "instances",
            )
                .select()
                .eq("id", instanceId)
                .maybeSingle();
        if (eventError) throw eventError;
        if (!event) {
            throw new HttpError(
                "No event found matching that instance_id",
                404,
                "event-not-found",
            );
        }

        // get any existing RSVP/invite
        const { data: existingRsvp, error: existingRsvpError } =
            await serviceRoleSupabase.from(
                "instance_members",
            )
                .select()
                .eq("instance", instanceId)
                .eq("member", currentUser.id)
                .maybeSingle();
        if (existingRsvpError) throw existingRsvpError;

        // branch actions
        const defaultSelect = '*, member(*)';
        let rsvp;
        if (status == null && existingRsvp && existingRsvp.created_by == currentUser.id) {
            // delete RSVP if user created it and they're removing their RSVP
            const { data: deletedRsvp, error: deletedRsvpError } = await serviceRoleSupabase.from(
                "instance_members",
            )
                .delete()
                .eq("id", existingRsvp.id)
                .select(defaultSelect)
                .single();
            if (deletedRsvpError) throw deletedRsvpError;

            deletedRsvp.status = null;
            rsvp = deletedRsvp;
        } else if (existingRsvp) {
            // update existing RSVP
            const { data: updatedRsvp, error: updatedRsvpError } = await serviceRoleSupabase.from(
                "instance_members",
            )
                .update({ status: status ?? 'invited' })
                .eq("id", existingRsvp.id)
                .select(defaultSelect)
                .single();
            if (updatedRsvpError) throw updatedRsvpError;

            rsvp = updatedRsvp;
        } else if (status) {
            // insert new RSVP
            const { data: insertedRsvp, error: insertedRsvpError } = await serviceRoleSupabase.from(
                "instance_members",
            )
                .insert({
                    created_by: currentUser.id, // must supply because we're running as service role
                    instance: instanceId,
                    member: currentUser.id,
                    status: status
                })
                .select(defaultSelect)
                .single();
            if (insertedRsvpError) throw insertedRsvpError;

            rsvp = insertedRsvp;
        } else {
            // posting null status to an RSVP that doesn't exist is a no-op
        }

        // return new RSVP
        return new Response(
            rsvp ? JSON.stringify(rsvp) : null,
            {
                headers: { "Content-Type": "application/json" },
                status: rsvp ? 200 : 204,
            },
        );
    } catch (error) {
        if (error instanceof HttpError) {
            let message = error.message;

            if (error.errorId) {
                message = `${error.errorId}: ${message}`;
            }

            return new Response(
                message,
                {
                    status: error.code,
                },
            );
        }

        return new Response(
            JSON.stringify({
                message: String(error?.message ?? error),
                error_id: error.errorId,
            }),
            {
                headers: { "Content-Type": "application/json" },
                status: 500,
            },
        );
    }
});
