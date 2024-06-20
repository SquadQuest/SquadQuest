CREATE VIEW location_tracks AS
SELECT
    *,
    ST_AsText(location) location_text,
    LAG(location, 1) OVER (
        PARTITION BY created_by
        ORDER BY
            timestamp
    ) previous_location,
    ST_Distance(
        location,
        LAG(location, 1) OVER (
            PARTITION BY created_by
            ORDER BY
                timestamp
        )
    ) distance,
    EXTRACT(
        EPOCH
        FROM
            timestamp - LAG(timestamp, 1) OVER (
                PARTITION BY created_by
                ORDER BY
                    timestamp
            )
    ) time_difference
FROM
    location_points
ORDER BY
    timestamp DESC;