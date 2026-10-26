# --
# Copyright (C) 2016 - 2022 Perl-Services.de, https://www.perl-services.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Maint::Ticket::ChecklistNotifications;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = qw(
    Kernel::System::PerlServices::TicketChecklistDueDate
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Send notifications for checklist items (due date will be reached shortly).');

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Send checklist notifications...</yellow>\n");

    my $ChecklistObject = $Kernel::OM->Get('Kernel::System::PerlServices::TicketChecklistDueDate');

    # do ticket auto jobs
    $ChecklistObject->Check();


    $Self->Print("<green>Done.</green>\n");
    return $Self->ExitCodeOk();
}

1;

=back

=head1 TERMS AND CONDITIONS

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (AGPL). If you
did not receive this file, see L<http://www.gnu.org/licenses/agpl.txt>.

=cut
