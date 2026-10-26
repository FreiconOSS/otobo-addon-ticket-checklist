# --
# Copyright (C) 2021 - 2022 Perl-Services.de, https://www.perl-services.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::PerlServices::TicketChecklistStartDate;

use strict;
use warnings;

our @ObjectDependencies = qw(
    Kernel::System::Log
    Kernel::System::PerlServices::TicketChecklist
);

use Kernel::System::EventHandler;

our @ISA = (
    'Kernel::System::EventHandler',
);

=head1 NAME

Kernel::System::PerlServices::TicketChecklistDueDate - backend for ticket checklists

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    $Self->EventHandlerInit(
        Config => 'TicketChecklist::EventModule',
    );

    return $Self;
}

sub Check {
    my ($Self) = @_;

    my $ChecklistObject = $Kernel::OM->Get('Kernel::System::PerlServices::TicketChecklist');

    my @Tasks = $ChecklistObject->DateStartItems();

    for my $Task ( @Tasks ) {
        $Self->EventHandler(
            Event => 'ItemDateStartBefore',
            Data  => {
                ItemID => $Task,
            },
            UserID => 1,
        );
    }
}

sub SetStartDateState {
    my ($Self) = @_;

    my $ChecklistObject = $Kernel::OM->Get('Kernel::System::PerlServices::TicketChecklist');
    my $ConfigObject    = $Kernel::OM->Get('Kernel::Config');

    my $NewState = $ConfigObject->Get('TicketChecklist::StartDate::NewState');

    return if !$NewState;

    my @Tasks = $ChecklistObject->StartedItems();

    for my $Task ( @Tasks ) {
        my %ItemData = $ChecklistObject->TicketChecklistGet(
            ID     => $Task,
            UserID => 1,
        );

        delete $ItemData{StatusID};

        $ChecklistObject->TicketChecklistUpdate(
            %ItemData,
            Status => $NewState,
            UserID => 1,
        );
    }
}

1;

=back

=head1 TERMS AND CONDITIONS

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (AGPL). If you
did not receive this file, see L<http://www.gnu.org/licenses/agpl.txt>.

=cut

