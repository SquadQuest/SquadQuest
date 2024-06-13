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
        const { friend_id: friendId, action } = await getRequiredJsonParameters(request, [
            "friend_id",
            "action"
        ]);

        if (action != 'accepted' && action != 'declined') {
            throw new HttpError("Action can only be one of: accept, decline", 400, 'invalid-action');
        }

        // connect to Supabase
        const serviceRoleSupabase = createServiceRoleSupabaseClient();
        const anonSupabase = createAnonSupabaseClient(request);

        // get current user
        const currentUser = await getSupabaseUser(anonSupabase, request);
        if (!currentUser) {
            throw new HttpError(
                "Authorized user not found",
                403,
                "authorized-user-not-found",
            );
        }

        // get friend
        const { data: friend, error: friendError } =
            await serviceRoleSupabase.from(
                "friends",
            )
                .select("*")
                .eq("id", friendId)
                .maybeSingle();
        if (friendError) throw friendError;
        if (!friend) {
            throw new HttpError(
                "No friend request found matching that id",
                404,
                "friend-not-found",
            );
        }

        // only allow action on requested status
        if (friend.status != 'requested') {
            throw new HttpError(
                "Friend is not in requested status",
                400,
                "not-requested-status",
            );
        }

        // update friend request
        const { data: updatedFriendRequest, error: updateError } =
            await serviceRoleSupabase.from("friends")
                .update({
                    status: action,
                    actioned_at: new Date()
                })
                .eq("id", friend.id)
                .select("*, requester(*), requestee(*)")
                .single();
        if (updateError) throw updateError;

        // return new friend request
        return new Response(
            JSON.stringify(updatedFriendRequest),
            {
                headers: { "Content-Type": "application/json" },
                status: 200,
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
