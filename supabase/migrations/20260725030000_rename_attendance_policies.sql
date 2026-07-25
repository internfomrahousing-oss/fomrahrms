-- HR found the seeded policy names confusing ("Standard Office" / "Sales
-- Field Staff" / "Unrestricted Field Staff" don't read as a coherent set).
-- Renames them to the mental model HR actually wants: one Office policy for
-- office employees, and two Check-in flavors for onsite/field employees —
-- Restricted (must be within an assigned location, single_location's sibling
-- multi_location) and Unrestricted (no location check at all).
--
-- Behavior is unchanged — policy_type/note_required_outside_radius are left
-- alone, this only touches the display name. Plain UPDATEs matched by the
-- old name, so this is a no-op (and safe to leave in migration history) once
-- already applied — including on a from-scratch bootstrap, where it runs
-- after 20260718030000_location_management.sql seeds the old names.

update attendance_policies set name = 'Office' where name = 'Standard Office';
update attendance_policies set name = 'Restricted Check-in' where name = 'Sales Field Staff';
update attendance_policies set name = 'Unrestricted Check-in' where name = 'Unrestricted Field Staff';
