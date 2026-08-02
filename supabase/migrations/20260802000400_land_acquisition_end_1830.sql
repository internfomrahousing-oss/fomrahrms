-- The office day ends at 18:30. Land Acquisition was created with 18:00, which
-- was an assumption carried over from the shape of the housekeeping row rather
-- than a stated requirement. They start at 09:00 and finish at 18:30 like
-- everyone else, so their working day is 9.5 hours.
--
-- Kept as a separate migration rather than only editing the earlier one, since
-- that migration has already been applied to production.
update office_timings
   set check_out_time = '18:30',
       working_hours  = '9.5'
 where name = 'Land Acquisition Hours';
