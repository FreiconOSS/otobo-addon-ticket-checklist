# --
# Kernel/Language/en_TicketChecklist.pm - the german translation for Checklists
# Copyright (C) 2015 - 2022 Perl-Services, https://www.perl-services.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Language::en_TicketChecklist;

use strict;
use warnings;

use utf8;

our $VERSION = 0.02;

sub Data {
    my $Self = shift;

    my $Lang = $Self->{Translation};

    return if ref $Lang ne 'HASH';

    $Lang->{'History::TicketChecklistItemAdd'} = 'Checklist item %s (Title: %s) added.';
    $Lang->{'History::TicketChecklistItemUpdate'} = 'Checklist item %s (Title: %s) updated.';
    $Lang->{'History::TicketChecklistItemResponsibleUpdate'} = 'New responsible for Checklist item %s (Title: %s): %s';
    $Lang->{'History::TicketChecklistItemDueDateUpdate'} = 'Due date for Checklist item %s (Title: %s) updated: %s';
    $Lang->{'History::TicketChecklistItemDelete'} = 'Checklist item %s (Title: %s) deleted.';
    $Lang->{'History::TicketChecklistItemStatusUpdate'} = 'Checklist item %s (Title: %s) changed state: %s -> %s.';

    $Lang->{"ChangeAgent"} = "Agent (state changer)";

    $Lang->{ItemDueDateBefore}     = 'Item is due';
    $Lang->{ItemsAllClosed}        = 'All items closed';
    $Lang->{ItemStatusUpdate}      = 'State of the item was updated';
    $Lang->{ItemChangeNote}        = 'Change note was updated';
    $Lang->{ItemResponsibleUpdate} = 'Itemresponsible was changed';
    $Lang->{ItemDelete}            = 'Item was deleted';


    return 1;
}

1;
