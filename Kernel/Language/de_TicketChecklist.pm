# --
# Copyright (C) 2014 - 2022 Perl-Services, https://www.perl-services.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Language::de_TicketChecklist;

use strict;
use warnings;

use utf8;

sub Data {
    my $Self = shift;

    my $Lang = $Self->{Translation};

    return if ref $Lang ne 'HASH';

    # Kernel/Config/Files/TicketChecklist.xml
    $Lang->{'Module to show checklists in tickets.'} = 'Modul zur Anzeige von Checklisten in Tickets.';
    $Lang->{'Shows a link in the ticket menu to manage the ticket checklist.'} = 'Zeigt einen Link im Ticketmenü zur Verwaltung der Ticket-Checkliste';
    $Lang->{'Checklist'} = 'Checkliste';
    $Lang->{'Maintain checklist for the ticket'} = 'Verwalten Sie eine Checkliste für das Ticket';
    $Lang->{'Enable/Disable debugging feature.'} = 'Ein-/Ausschalten des Debuggings';
    $Lang->{'No'} = 'Nein';
    $Lang->{'Yes'} = 'Ja';
    $Lang->{'Frontend module registration for ticket checklist module.'} =
        'Frontendmodul-Registration für das Checklisten-Modul.';
    $Lang->{'Frontend module registration for the checklist state administration.'} = 'Frontendmodul-Registration für das Checklisten-Status Modul.';
    $Lang->{'Create and manage checklist states.'} = 'Erstellen und Verwalten von Checklist Status.';
    $Lang->{'Checklist States'} = 'Checklist Status';
    $Lang->{'Maintain ticket checklists'}  = 'Ticketchecklisten pflegen';
    $Lang->{'Maintain ticket checklists.'}  = 'Ticketchecklisten pflegen.';

    # Custom/Kernel/Output/HTML/Templates/Standard/AdminTicketChecklistStateList.tt
    $Lang->{'Checklist Item State Management'} = 'Checklisten Status Verwaltung';
    $Lang->{'Actions'} = 'Aktionen';
    $Lang->{'Add State'} = 'Status hinzufügen';
    $Lang->{'List'} = 'Liste';
    $Lang->{'ID'} = 'ID';
    $Lang->{'Name'} = 'Name';
    $Lang->{'Valid'} = 'Gültig';
    $Lang->{'No matches found.'} = 'Keine Treffer gefunden.';
    $Lang->{'edit'} = 'bearbeiten';
    $Lang->{'delete'} = 'löschen';

    # Custom/Kernel/Output/HTML/Templates/Standard/AdminTicketChecklistStateForm.tt
    $Lang->{'Go to overview'} = 'Zur Übersicht';
    $Lang->{'Add/Change States'} = 'Status Hinzufügen / Ändern';
    $Lang->{'done'} = 'erledigt';
    $Lang->{'A name is required.'} = 'Ein Name muss angegeben werden';
    $Lang->{'Color'} = 'Farbe';
    $Lang->{'A color is required.'} = 'Eine Farbe muss angegeben werden';
    $Lang->{'Save'} = 'Speichern';
    $Lang->{'or'} = 'oder';
    $Lang->{'Cancel'} = 'Abbrechen';

    # Custom/Kernel/Output/HTML/Templates/Standard/AgentTicketChecklist.tt
    $Lang->{'Manage Checklist for ticket'} = 'Verwalten Sie eine Checkliste für das Ticket';
    $Lang->{'Cancel & close window'} = 'Abbrechen und Fenster schließen';
    $Lang->{'Toggle this widget'} = 'Dieses Widget umschalten';
    $Lang->{'Checklist Settings'} = 'Checkliste Einstellungen';
    $Lang->{'Remove item'} = 'Punkt löschen';
    $Lang->{'Add item'} = 'Punkt hinzufügen';
    $Lang->{'Submit'} = 'Abschicken';

    # Custom/Kernel/Output/HTML/Templates/Standard/TicketChecklistWidget.tt
    $Lang->{'Show or hide the content'} = 'Inhalt anzeigen oder ausblenden';
    $Lang->{'Ticket Checklist'} = 'Ticket Checkliste';

    # Custom/Kernel/Modules/AgentTicketChecklist.pm
    $Lang->{'No TicketID is given!'} = 'Keine TicketID übergeben!';
    $Lang->{'Please contact the admin.'} = 'Bitte kontaktieren Sie den Administrator.';
    $Lang->{'You need %s permissions!'} = 'Sie benötigen %s-Rechte!';

    # TicketChecklist.sopm (default TicketChecklist states)
    $Lang->{'open'} = 'offen';
    $Lang->{'waiting'} = 'warten';
    $Lang->{'rejected'}  = 'abgelehnt';
    $Lang->{'done'}  = 'erledigt';

    $Lang->{'My Todos'} = 'Meine Aufgaben';
    $Lang->{'Ticket Title'} = 'Tickettitel';
    $Lang->{'My Checklist Todos'} = 'Meine Checklisten-Aufgaben';

    $Lang->{'Search Checklist Tickets'} = 'Suche Tickets mit Checkliste';
    $Lang->{'Checklist Tickets'} = 'Checklisten-Tickets';
    $Lang->{'Tickets/Open Checklists'} = 'Tickets (offene Checklisten)';
    $Lang->{'Tickets/Other Checklists'} = 'Tickets (andere Checklisten)';

    $Lang->{'Checklist Template Management'} = 'Checklistentemplates verwalten';
    $Lang->{'Checklist Item State Management'} = 'Checklisten-Status verwalten';
    $Lang->{'Checklist States'} = 'Checklisten-Status';
    $Lang->{'Create and manage checklist states.'} = 'Checklisten-Status erstellen und verwalten.'; 
    $Lang->{'Checklist Templates'} = 'Checklisten-Vorlagen';
    $Lang->{'Create and manage checklist templates.'} = 'Checklisten-Vorlagen erstellen und verwalten.';
    $Lang->{'Add/Change States'} = 'Status hinzufügen/ändern';
    $Lang->{'Add/Change Templates'} = 'Vorlagen hinzufügen/ändern';

    $Lang->{'Color'} = 'Farbe';
    $Lang->{'edit'}  = 'bearbeiten';
    $Lang->{'delete'} = 'löschen';
    $Lang->{'Due Date'} = 'Fälligkeit';
    $Lang->{'DueDate'} = 'Fälligkeit';
    $Lang->{'Checklist Items'} = 'Checklisten-Aufgaben';
    $Lang->{'TicketTitle'} = 'Tickettitel';
    $Lang->{'Tickets with Checklist Items'} = 'Tickets mit Checklisten-Aufgaben';
    $Lang->{'All checklist items for an user'} = 'Alle Checklisten-Aufgeben für einen Agenten';
    $Lang->{'All tickets with checklist items for an user'} = 'Alle Tickets mit Checklisten-Aufgeben für einen Agenten';

    $Lang->{'Checklist Settings'}  = 'Checklist Einstellungen';
    $Lang->{'Ticket Checklist'}  = 'Ticket Checkliste';

    $Lang->{'Checklist item %s (Title: %s) added.'} = 'Checklistenpunkt %s (Titel: %s) erstellt.';
    $Lang->{'Checklist item %s (Title: %s) updated.'} = 'Checklistenpunkt %s (Titel: %s) aktualisiert.';
    $Lang->{'New responsible for Checklist item %s (Title: %s): %s'} = 'Neuer Verantwortlicher für Checklistenpunkt %s (Titel: %s): %s';
    $Lang->{'Due date for Checklist item %s (Title: %s) updated: %s'} = 'Fälligkeit für Checklistenpunkt %s (Titel: %s) aktualisiert: %s';
    $Lang->{'Checklist item %s (Title: %s) deleted.'} = 'Checklistenpunkt %s (Titel: %s) gelöscht.';
    $Lang->{'Checklist item %s (Title: %s) changed state: %s -> %s.'} = 'Neuer Status für Checklistenpunkt %s (Titel: %s): %s -> %s.';
    $Lang->{'Checklist item %s (Title: %s) moved to ticket id %s.'} = 'Aufgabe %s (Titel: %s) wurde zu Ticket ID %s verschoben';

    $Lang->{"Confirm item deletion"} = 'Bestätige das Löschen des Todo-Punkts';
    $Lang->{"Do you want to delete this item?"} = 'Wollen Sie diesen Punkt wirklich löschen?';
    $Lang->{"Show/Hide all details"} = 'Zeige/Verstecke alle Details';

    $Lang->{'Article #'} = 'Artikel #';
    $Lang->{"Add items to existing checklist"} = 'Fügt Punkte zur bestehenden Checkliste hinzu';

    $Lang->{'Change Note'} = 'Änderungsnotiz';
    $Lang->{'Checklists per Ticket'} = 'Checklisten pro Ticket';
    $Lang->{"The estimated effort for this task (in minutes)"} = "Der geschätzte Aufwand für diese Aufgabe (in Minuten)";
    $Lang->{"Checklist Notifications"} = "Checklistenbenachrichtigungen";
    $Lang->{"Create and manage checklist notifications."} = "Checklistenbenachrichtigungen erstellen und verwalten";

    $Lang->{"Conditions and Actions"} = 'Bedingungen und Aktionen';
    $Lang->{"Checklist item"}         = 'Aufgabe';
    $Lang->{"New Status"}             = 'Neuer Status';
    $Lang->{'Action Module'}          = 'Aktionsmodul';
    $Lang->{'Add Parameter'}          = 'Parameter hinzufügen';

    $Lang->{'The default state for a new checklist item.'} = 'Standardstatus für einen neuen Checklistenpunkt';
    $Lang->{'in progress'} = 'in Bearbeitung';
    $Lang->{'waiting'}     = 'warten';

    $Lang->{"Only my todos"} = 'Nur meine Aufgaben';
    $Lang->{"Export to"}     = 'Exportieren als';
    $Lang->{"PDF"}           = 'PDF';
    $Lang->{"Excel file"}    = 'Exceldatei';
    $Lang->{"ICal Todo"}     = 'Kalender-Aufgabe';
    $Lang->{"copy"}          = 'kopieren';

    $Lang->{"Default priority for checklist items (ticket priorities are used)"} = 'Standardpriorität für Aufgaben (Ticketprioritäten werden verwendet).';
    $Lang->{'"open" states for checklist items'} = '"offen"-Status für Aufgaben';
    $Lang->{'View mode for Checklist widget.'}   = 'Ansichtsmodus für Checklisten-Widget';
    $Lang->{'Position for Checklist widget (only for Simple mode).'} = 'Position des Checklisten-Widgets (nur für den "Simple"-Modus';
    $Lang->{"If enabled, all users can be selected as a responsible. If disabled, only users with ro permission on the tickets' queue can be selected as a responsible."} = '';
    $Lang->{'Show checklist actions in history.'} = '';
    $Lang->{'If enabled, items are added when the template is changed (instead of overridden)'} = '';
    $Lang->{'If enabled, items are deleted from database'} = '';
    $Lang->{'If enabled, confirmation is needed to delete items'} = '';
    $Lang->{'If enabled, a widget with checklist items is shown in the ticket create'} = '';
    $Lang->{'If enabled, items are added when the template is changed (instead of overridden)'} = '';
    $Lang->{'If enabled, the todo item comment is included in the ticket PDF.'} = '';
    $Lang->{'New state for checklist items when a ticket is closed'} = '';
    $Lang->{'Name of the dynamic field for keeping the state of open todos.'} = '';
    $Lang->{"Defines where the 'export' (currently xls, ical, pdf) icons are shown."} = '';
    $Lang->{'If enabled, existing templates will be overriden if a template with the same name exists in the import'} = '';
    $Lang->{'Define how the task details are shown in the widget'} = '';
    $Lang->{'Show on Mouseover'} = 'Beim überfahren mit der Maus anzeigen';
    $Lang->{'Do not show Details'} = 'Details nicht anzeigen';
    $Lang->{'Show Link'} = 'Link anzeigen';

    $Lang->{'If enabled, agents can add notes to the item when they change them.'} = '';
    $Lang->{'If enabled, agents can add notes to the item when they change the states via the widget.'} = '';
    $Lang->{'If enabled, change notes are added to the ticket.'} = '';
    $Lang->{'If enabled, change notes are sent as notifications.'} = '';
    $Lang->{'Article type for change note articles.'} = '';
    $Lang->{'Subject for change note articles.'} = '';
    $Lang->{'If enabled, change notes are added to the todo item.'} = '';
    $Lang->{'If enabled, change notes are editable in the todo item.'} = '';
    $Lang->{'Number of rows for the change note.'} = '';
    $Lang->{'Number of columns for the change note.'} = '';

    $Lang->{'Add checklist to ticket.'} = 'Füge Checklisten zum Ticket hinzu';

    $Lang->{'Send Notifications.'} = 'Sende Benachrichtigungen.';
    $Lang->{'Update TicketHistory.'} = 'Aktualisiere Tickethistorie.';
    $Lang->{'Add ChangeNote to ticket.'} = 'Füge Änderungsnotiz zum Ticket hinzu.';
    $Lang->{'Set ticket dynamic field to keep track if any item is open.'} = 'Setze das Dynamische Feld am Ticket, das protokolliert ob irgendeine Aufgabe noch offen ist.';
    $Lang->{'Check the conditions and run the actions.'} = 'Prüfen die Bedingungen und starte die Aktionen';
    $Lang->{'Set ticket dynamic field to keep track if the ticket has a checklist.'} = 'Setze das Dynamische Feld am Ticket, das protokolliert ob eine Checkliste am Ticket existiert';

    $Lang->{'Merge ticket checklists when tickets are merged.'} = 'Führe Ticketchecklisten zusammen wenn Tickets zusammengeführt werden';
    $Lang->{'Close checklist items when tickets are closed.'} = 'Schließe Aufgaben wenn das Ticket geschlossen wird';
    $Lang->{'Set ticket checklists when tickets are created via webinterface.'} = 'Setze die Ticketcheckliste wenn ein Ticket über die Weboberfläche erstellt wird.';

    $Lang->{'Frontend module registration for the checklist template administration.'} = '';
    $Lang->{'Frontend module registration for the checklist notification administration.'} = '';

    $Lang->{'Dashboard widget for checklist items.'} = '';
    $Lang->{'Dashboard widget for tickets with checklist items.'} = '';

    $Lang->{'Frontend module registration for the AgentTicketChecklistIDSet.'} = '';
    $Lang->{'Frontend module registration for the AgentTicketChecklistTemplates.'} = '';
    $Lang->{'Frontend module registration for the AgentTicketPrintChecklist.'} = '';
    $Lang->{'Frontend module registration for the AgentTicketChecklistResponsibleSearch.'} = '';
    $Lang->{'Frontend module registration for the AgentTicketChangeChecklistStatus.'} = '';

    $Lang->{'Shows a link in the menu to the ticket checklist.'} = 'Zeigt einen Link zur Checkliste im Ticketmenü';

    $Lang->{"Move task to Ticket"} = 'Verschiebe Aufgabe nach Ticket';
    $Lang->{"Move to Ticket#"}     = 'Verschiebe zu Ticket#';
    $Lang->{"Moved task to Ticket"} = 'Aufgabe wurde zum Ticket verschoben';
    $Lang->{'Cound not move task to Ticket'} = 'Konnte Aufgabe nicht zum Ticket verschieben';

    $Lang->{'Checklist has hidden items.'} = 'Die Checkliste enthält versteckte Aufgaben';
    $Lang->{'Show all items'} = 'Zeige alle Aufgaben';
    $Lang->{'Hide items'} = 'Verstecke Aufgaben';
    $Lang->{'Clear checklist'} = 'Checkliste löschen';
    $Lang->{'Set priority for all items to ticket priority'} = 'Setze Ticketpriorität für alle Aufgaben';

    $Lang->{"State cannot be delete. A checklist item uses this state."} = 'Der Status kann nicht gelöscht werden. Eine Aufgabe nutzt noch diesen Status.';
    $Lang->{"Export all templates"} = 'Alle Vorlagen exportieren';
    $Lang->{'No permission to save the checklist!'} = 'Keine Berechtigung zum speichern der Checkliste!';

    $Lang->{"customerportal"} = "Kundenportal";

    $Lang->{"Shown Items"} = "Angezeigte Aufgaben";
    $Lang->{"Show Agent who changed the state"} = "Zeige Agenten, der den Status geändert hat";
    $Lang->{"ChangeAgent"} = "Agent (Status geändert)";

    $Lang->{Subscribe} = 'Aktiviert';
    $Lang->{'Checklist notifications'} = 'Checklisten-Benachrichtigungen';
    $Lang->{'Choose for which kind of checklist changes you want to receive notifications.'} =
        'Wähle für welche Checklisten-Änderungen Du Benachrichten erhalten möchtest';

    $Lang->{ItemDueDateBefore}     = 'TODO wird fällig';
    $Lang->{ItemDueDateUpdate}     = 'Fälligkeitsdatum wurde aktualisiert';
    $Lang->{ItemsAllClosed}        = 'Alle TODOs geschlossen';
    $Lang->{ItemStatusUpdate}      = 'Statusupdate eines TODOs';
    $Lang->{ItemChangeNote}        = 'Änderungsnotiz eines TODOs';
    $Lang->{ItemResponsibleUpdate} = 'Änderung des Verantwortlichen eines TODOs';
    $Lang->{ItemDelete}            = 'TODO wurde gelöscht';
    $Lang->{ItemDateStartBefore}   = 'TODO startet';
    $Lang->{ItemDateStartUpdate}   = 'Startdatum wurde aktualisiert';

    $Lang->{'Start Date'} = 'Startdatum';
    $Lang->{'DateStart'} = 'Startdatum';
    $Lang->{'Minutes the item should start after checklist creation'} =
        'Minuten, die der Entrag nach Erstellung der Checkliste starten soll';

    $Lang->{'Items from Textarea'} = 'Aufgaben aus Textfeld';
    $Lang->{'A due date must not be in the past.'} = 'Ein Fälligkeitsdatum darf nicht in der Vergangenheit liegen';
    $Lang->{'The start date must be before the due date.'} = 'Das Startdatum muss vor dem Fälligkeitsdatum liegen';

    return 1;
}

1;
