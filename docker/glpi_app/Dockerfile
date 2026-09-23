FROM glpi/glpi:11.0.8

USER root

# Intégration des personnalisations "État détaillé + historique des consommables"
# (patch core GLPI : Consumable / ConsumableItem / Dropdown / ConsumableState + template)
COPY custom/src/Consumable.php /var/www/glpi/src/Consumable.php
COPY custom/src/ConsumableItem.php /var/www/glpi/src/ConsumableItem.php
COPY custom/src/Dropdown.php /var/www/glpi/src/Dropdown.php
COPY custom/src/ConsumableState.php /var/www/glpi/src/ConsumableState.php
COPY custom/front/consumablestate.php /var/www/glpi/front/consumablestate.php
COPY custom/front/consumablestate.form.php /var/www/glpi/front/consumablestate.form.php
COPY custom/ajax/consumable.php /var/www/glpi/ajax/consumable.php
COPY custom/templates/pages/assets/consumable_list.html.twig /var/www/glpi/templates/pages/assets/consumable_list.html.twig

# Plugin glpi-inventory 1.6.10 (open source)
COPY custom/plugins/glpiinventory /var/www/glpi/plugins/glpiinventory

USER www-data