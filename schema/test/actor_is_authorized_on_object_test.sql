BEGIN;

SELECT no_plan();

SELECT is_strict('actor_has_permission_on_object', ARRAY['character', 'character', 'auth_permission']);
SELECT volatility_is('actor_has_permission_on_object', ARRAY['character', 'character', 'auth_permission'], 'stable');
SELECT function_returns('public', 'actor_has_permission_on_object', ARRAY['character', 'character', 'auth_permission'], 'boolean');

-- Testing Data

INSERT INTO auth_group(authz_id)
VALUES
       ('aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'),
       ('bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'),
       ('cccccccccccccccccccccccccccccccc');

INSERT INTO auth_actor(authz_id)
VALUES
       ('zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz'),
       ('yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy'),
       ('xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'),
       ('wwwwwwwwwwwwwwwwwwwwwwwwwwwwwwww');

INSERT INTO group_group_relations(parent, child)
VALUES
       (group_id('aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'), group_id('bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb')),
       (group_id('bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'), group_id('cccccccccccccccccccccccccccccccc'));

INSERT INTO group_actor_relations(parent, child)
VALUES
       (group_id('bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'), actor_id('yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy')),
       (group_id('aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'), actor_id('xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'));

INSERT INTO auth_object(authz_id)
VALUES
        ('oooooooooooooooooooooooooooooooo');

INSERT INTO object_acl_group(target, authorizee, permission)
VALUES
        (object_id('oooooooooooooooooooooooooooooooo'), group_id('bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'), 'read'),
        (object_id('oooooooooooooooooooooooooooooooo'), group_id('aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'), 'delete')
        ;

INSERT INTO object_acl_actor(target, authorizee, permission)
VALUES
        (object_id('oooooooooooooooooooooooooooooooo'), actor_id('zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz'), 'update'),
        (object_id('oooooooooooooooooooooooooooooooo'), actor_id('xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'), 'delete');


-- Test the basic cases:
--
-- Actor has direct permission
-- Actor has indirect permission (i.e. is in a group with the permission)
-- Actor has indirect permission via nested groups (i.e. is in a group in a group with the permission)
-- Actor has both direct and indirect permission
-- Actor has no permission
SELECT is(TRUE,
       actor_has_permission_on_object('zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz', 'oooooooooooooooooooooooooooooooo', 'update'),
       'An actor directly granted permission XXX has the XXX permission');
SELECT is(TRUE,
       actor_has_permission_on_object('xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx', 'oooooooooooooooooooooooooooooooo', 'delete'),
       'An actor both directly and indirectly granted permission XXX has the XXX permission');
SELECT is(TRUE,
       actor_has_permission_on_object('yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy', 'oooooooooooooooooooooooooooooooo', 'read'),
       'An actor indirectly granted permission XXX has the XXX permission');
SELECT is(TRUE,
       actor_has_permission_on_object('yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy', 'oooooooooooooooooooooooooooooooo', 'delete'),
       'An actor indirectly granted permission XXX via nested groups has the XXX permission');
SELECT is(FALSE,
       actor_has_permission_on_object('wwwwwwwwwwwwwwwwwwwwwwwwwwwwwwww', 'oooooooooooooooooooooooooooooooo', 'grant'),
       'An actor neither directly nor indirectly granted permission XXX does NOT have the XXX permission');

-- Verify behavior on NULL input
SELECT is(NULL,
       actor_has_permission_on_object(NULL, 'oooooooooooooooooooooooooooooooo', 'update'),
       'actor_has_permission_on_object returns NULL if actor is NULL');
SELECT is(NULL,
       actor_has_permission_on_object('zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz', NULL, 'update'),
       'actor_has_permission_on_object returns NULL if object is NULL');
SELECT is(NULL,
       actor_has_permission_on_object('zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz', 'oooooooooooooooooooooooooooooooo', NULL),
       'actor_has_permission_on_object returns NULL if permission is NULL');

-- Verify behavior when passed non-NULL, but still invalid data (i.e., invalid permission, non-existent actor, non-existent object)
SELECT throws_ok(
       $$SELECT actor_has_permission_on_object('zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz', 'qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq', 'update')$$,
       '22004',
       'null value cannot be assigned to variable "object_id" declared NOT NULL',
       'Checking of permission on non-existent object throws an exception');
SELECT throws_ok(
       $$SELECT actor_has_permission_on_object('qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq', 'oooooooooooooooooooooooooooooooo', 'update')$$,
       '22004',
       'null value cannot be assigned to variable "actor_id" declared NOT NULL',
       'Checking of permission for non-existent actor throws an exception');
SELECT throws_ok(
       $$SELECT actor_has_permission_on_object('zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz', 'oooooooooooooooooooooooooooooooo', 'license_to_kill')$$,
       '22P02',
       'invalid input value for enum auth_permission: "license_to_kill"',
       'Checking a non-existent permission throws an exception');

SELECT finish();
ROLLBACK;
