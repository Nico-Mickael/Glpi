<?php

/**
 * ---------------------------------------------------------------------
 *
 * GLPI - Gestionnaire Libre de Parc Informatique
 *
 * http://glpi-project.org
 *
 * @copyright 2015-2026 Teclib' and contributors.
 * @licence   https://www.gnu.org/licenses/gpl-3.0.html
 *
 * ---------------------------------------------------------------------
 *
 * AJAX endpoint for consumable SPA operations.
 * Follows the native GLPI 11 ajax pattern (bootstrapped by the Kernel).
 */

use Glpi\Event;
use function Safe\json_encode;

header('Content-Type: application/json; charset=UTF-8');
Html::header_nocache();

// CSRF protection is handled by Glpi\Kernel\Listener\ControllerListener\CheckCsrfListener
// (token check via "X-Glpi-Csrf-Token" header on AJAX XHR requests).

if (Session::getLoginUserID() === false) {
    http_response_code(403);
    echo json_encode(['success' => false, 'message' => 'Not authenticated']);
    return;
}

$action = $_POST['action'] ?? $_GET['action'] ?? '';

if ($action === 'counts') {
    $consumableitem_id = (int)($_POST['consumableitems_id'] ?? $_GET['consumableitems_id'] ?? 0);

    if (!$consumableitem_id) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Missing consumableitems_id']);
        return;
    }

    echo json_encode([
        'success'      => true,
        'count_unused' => Consumable::getUnusedNumber($consumableitem_id),
        'count_used'   => Consumable::getOldNumber($consumableitem_id),
        'count_total'  => Consumable::getTotalNumber($consumableitem_id),
    ]);
    return;
}

if ($action === 'add') {
    $consumableitem_id = (int)($_POST['consumableitems_id'] ?? 0);
    $to_add = max(1, (int)($_POST['to_add'] ?? 1));

    if (!$consumableitem_id) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Missing consumableitems_id']);
        return;
    }

    // Same right check as the core `front/consumable.form.php` "add_several" handler.
    $constype = new ConsumableItem();
    if (
        !$constype->getFromDB($consumableitem_id)
        || !$constype->canUpdate()
        || !$constype->canUpdateItem()
    ) {
        http_response_code(403);
        echo json_encode(['success' => false, 'message' => htmlescape(__('No right to update this consumable'))]);
        return;
    }

    $con = new Consumable();
    $added = 0;
    for ($i = 0; $i < $to_add; $i++) {
        unset($con->fields['id']);
        if ($con->add(['consumableitems_id' => $consumableitem_id])) {
            $added++;
        }
    }

    Event::log(
        $consumableitem_id,
        "consumableitems",
        4,
        "inventory",
        //TRANS: %s is the user login
        sprintf(__('%s adds consumables'), $_SESSION["glpiname"])
    );

    echo json_encode([
        'success'      => $added > 0,
        'added'        => $added,
        'message'      => $added > 0
            ? htmlescape(sprintf(__('%d consumable(s) added'), $added))
            : htmlescape(__('Failed to add consumables')),
        'count_unused' => Consumable::getUnusedNumber($consumableitem_id),
        'count_used'   => Consumable::getOldNumber($consumableitem_id),
        'count_total'  => Consumable::getTotalNumber($consumableitem_id),
        'csrf_token'   => Session::getNewCSRFToken(),
    ]);
    return;
}

if ($action === 'backToStock') {
    $id = (int)($_POST['id'] ?? 0);
    $consumablestates_id = (int)($_POST['consumablestates_id'] ?? 2);
    $motif = trim((string)($_POST['motif'] ?? ''));

    if (!$id) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Missing consumable id']);
        return;
    }

    $consumable = new Consumable();
    if (!$consumable->can($id, UPDATE)) {
        http_response_code(403);
        echo json_encode(['success' => false, 'message' => htmlescape(__('No right to update this consumable'))]);
        return;
    }

    $result = $consumable->backToStock([
        'id'                  => $id,
        'consumablestates_id' => $consumablestates_id,
        'motif'               => $motif,
    ]);

    echo json_encode([
        'success' => $result,
        'message' => $result
            ? htmlescape(__('Consumable returned to stock'))
            : htmlescape(__('Failed to return consumable')),
    ]);
    return;
}

if ($action === 'give') {
    $id = (int)($_POST['id'] ?? 0);
    $itemtype = $_POST['give_itemtype'] ?? '';
    $items_id = (int)($_POST['give_items_id'] ?? 0);

    if (!$id || !$itemtype || !$items_id) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Missing required parameters']);
        return;
    }

    $consumable = new Consumable();
    if (!$consumable->can($id, UPDATE)) {
        http_response_code(403);
        echo json_encode(['success' => false, 'message' => htmlescape(__('No right to update this consumable'))]);
        return;
    }

    $result = $consumable->out($id, $itemtype, $items_id);

    echo json_encode([
        'success' => $result,
        'message' => $result
            ? htmlescape(__('Consumable given'))
            : htmlescape(__('Failed to give consumable')),
    ]);
    return;
}

http_response_code(400);
echo json_encode(['success' => false, 'message' => 'Unknown action: ' . htmlescape($action)]);