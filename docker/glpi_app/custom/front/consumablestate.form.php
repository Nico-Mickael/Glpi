<?php
/**
 * A copier dans : front/consumablestate.form.php
 */

require_once(__DIR__ . '/_check_webserver_config.php');

$state = new ConsumableState();

if (isset($_POST["add"])) {
    $state->check(-1, CREATE, $_POST);
    $newID = $state->add($_POST);
    Html::back();
} elseif (isset($_POST["delete"])) {
    $state->check($_POST['id'], DELETE);
    $state->delete($_POST);
    $state->redirectToList();
} elseif (isset($_POST["restore"])) {
    $state->check($_POST['id'], PURGE);
    $state->restore($_POST);
    $state->redirectToList();
} elseif (isset($_POST["purge"])) {
    $state->check($_POST['id'], PURGE);
    $state->delete($_POST, 1);
    $state->redirectToList();
} elseif (isset($_POST["update"])) {
    $state->check($_POST['id'], UPDATE);
    $state->update($_POST);
    Html::back();
} else {
    Html::header(
        ConsumableState::getTypeName(1),
        $_SERVER['PHP_SELF'],
        "config",
        "consumablestate"
    );
    $state->display(['id' => $_GET['id']]);
    Html::footer();
}
