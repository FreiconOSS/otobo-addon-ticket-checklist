# --
# Copyright (C) 2018 - 2022 Perl-Services.de, https://www.perl-services.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Maint::Ticket::ChecklistClearPreferences;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = qw(
    Kernel::System::User
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Clear the preference settings that defines for which tickets the hidden items should be shown.');

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Clear preferences...</yellow>\n");

    my $UserObject = $Kernel::OM->Get('Kernel::System::User');
    my %FoundUsers = $UserObject->SearchPreferences(
        Key => 'PSTicketChecklistShowHiddenItems',
    );

    for my $UserID ( sort keys %FoundUsers ) {
        $Self->Print("<yellow>Clear preferences for UserID $UserID...</yellow>\n");
        $UserObject->SetPreferences(
            Key    => 'PSTicketChecklistShowHiddenItems',
            Value  => '',
            UserID => $UserID,
        );
    }

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
