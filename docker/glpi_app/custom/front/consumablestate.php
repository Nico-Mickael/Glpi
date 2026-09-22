<?php
/**
 * A copier dans : front/consumablestate.php
 */

require_once(__DIR__ . '/_check_webserver_config.php');

Html::header(
    ConsumableState::getTypeName(Session::getPluralNumber()),
    $_SERVER['PHP_SELF'],
    "config",
    "consumablestate"
);

Search::show('ConsumableState');

Html::footer();
