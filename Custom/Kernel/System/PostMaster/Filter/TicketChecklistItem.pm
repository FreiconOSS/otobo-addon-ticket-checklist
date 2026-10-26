# --
# Copyright (C) 2015 - 2022 Perl-Services.de, https://www.perl-services.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::PostMaster::Filter::TicketChecklistItem;

use strict;
use warnings;

use List::Util qw(first);

our @ObjectDependencies = qw(
    Kernel::Config
    Kernel::System::Log
    Kernel::System::Ticket
    Kernel::System::Time
    Kernel::System::PerlServices::TicketChecklistTemplate
    Kernel::System::PerlServices::TicketChecklist
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = { %Param };
    bless( $Self, $Type );

    $Self->{Debug} = $Param{Debug} || 0;

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $LogObject       = $Kernel::OM->Get('Kernel::System::Log');
    my $ChecklistObject = $Kernel::OM->Get('Kernel::System::PerlServices::TicketChecklist');
    my $TimeObject      = $Kernel::OM->Get('Kernel::System::Time');

    if ( $Self->{Debug} >= 1 ) {
        $LogObject->Log(
            Priority => 'debug',
            Message  => "starting Filter $Param{JobConfig}->{Name}",
        );
    }

    if ( !$Param{TicketID} ) {
        return 1;
    }

    my %Mail = %{ $Param{GetParam} || {} };

    my @ItemKeys = grep{
        $_ =~ m{\A X-OTRS-TicketChecklistItem- [0-9]+ \z }xms;
    } keys %Mail;

    my @ChecklistItems = $ChecklistObject->TicketChecklistTicketGet(
        TicketID => $Param{TicketID},
    );

    my %DeleteIfIsGiven = (
        StatusID => 'Status',
    );

    my @Attributes = qw(
        StatusID Status PriorityID DueDate ResponsibleID
    );

    KEY:
    for my $Key ( @ItemKeys ) {
        my $Name = $Mail{$Key};

        my ($Item) = first{ $_->{Title} eq $Name } @ChecklistItems;

        next KEY if !$Item;

        my %ItemData = $ChecklistObject->TicketChecklistGet(
            ID => $Item->{ID},
        );

        ATTRIBUTE:
        for my $Attribute ( @Attributes ) {
            my $MailValue = $Mail{ $Key . '-' . $Attribute };

            if ( defined $MailValue and length $MailValue ) {
                $ItemData{$Attribute} = $Mail{ $Key . '-' . $Attribute };

                if ( $DeleteIfIsGiven{$Attribute} ) {
                    my $DeleteKey = $DeleteIfIsGiven{$Attribute};
                    delete $ItemData{$DeleteKey};
                }
            }
        }

        $ChecklistObject->TicketChecklistUpdate(
            %ItemData,
            TicketID => $Param{TicketID},
            ID       => $Item->{ID},
            UserID   => $Param{UserID},
        );
    }

    return 1;
}

1;
