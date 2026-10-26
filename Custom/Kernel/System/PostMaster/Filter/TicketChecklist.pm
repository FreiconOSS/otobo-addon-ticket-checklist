# --
# Copyright (C) 2015 - 2022 Perl-Services.de, https://www.perl-services.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::PostMaster::Filter::TicketChecklist;

use strict;
use warnings;

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
    my $TemplateObject  = $Kernel::OM->Get('Kernel::System::PerlServices::TicketChecklistTemplate');
    my $ChecklistObject = $Kernel::OM->Get('Kernel::System::PerlServices::TicketChecklist');
    my $TimeObject      = $Kernel::OM->Get('Kernel::System::Time');

    if ( $Self->{Debug} >= 1 ) {
        $LogObject->Log(
            Priority => 'debug',
            Message  => "starting Filter $Param{JobConfig}->{Name}",
        );
    }

    my %Mail = %{ $Param{GetParam} || {} };

    my $IsFollowUp = $Param{Return} && $Param{Return} > 1;
    my $TemplateID;

    if ( !$IsFollowUp && ( $Mail{'X-OTRS-TicketChecklistID'} || $Mail{'X-OTRS-TicketChecklistName'} ) ) {

        $TemplateID = $Mail{'X-OTRS-TicketChecklistID'};

        if ( $Mail{'X-OTRS-TicketChecklistName'} ) {
            $TemplateID = $TemplateObject->TemplateNameExists(
                Name => $Mail{'X-OTRS-TicketChecklistName'},
            );
        }
    }
    elsif ( $IsFollowUp && ( $Mail{'X-OTRS-FollowUp-TicketChecklistID'} || $Mail{'X-OTRS-FollowUp-TicketChecklistName'} ) ) {

        $TemplateID = $Mail{'X-OTRS-FollowUp-TicketChecklistID'};

        if ( $Mail{'X-OTRS-FollowUp-TicketChecklistName'} ) {
            $TemplateID = $TemplateObject->TemplateNameExists(
                Name => $Mail{'X-OTRS-FollowUp-TicketChecklistName'},
            );
        }
    }

    return 1 if !$TemplateID;

    # get template
    my %Template = $TemplateObject->TemplateGet(
        ID => $TemplateID,
    );

    return 1 if !%Template || !$Template{Items};

    # save items
    my $PosCounter = 1;
    for my $Item ( @{ $Template{Items} } ) {
        my $DueDate;

        if ( $Item->{DueDateDiff} ) {
            $DueDate = $TimeObject->SystemTime2TimeStamp(
                SystemTime => $TimeObject->SystemTime() + ( $Item->{DueDateDiff} * 60 ),
            );
        }

        my $DateStart;

        if ( $Item->{DateStartDiff} ) {
            $DateStart = $TimeObject->SystemTime2TimeStamp(
                SystemTime => $TimeObject->SystemTime() + ( $Item->{DateStartDiff} * 60 ),
            );
        }

        my $StatusID = delete $Item->{Status};

        $ChecklistObject->TicketChecklistAdd(
            %{$Item},
            StatusID      => $StatusID,
            Position      => $PosCounter,
            PriorityID    => $Item->{Priority},
            ResponsibleID => $Item->{Responsible} || $Param{UserID} || 1,
            DueDate       => $DueDate,
            DateStart     => $DateStart,
            TicketID      => $Param{TicketID},
            UserID        => $Self->{PostmasterUserID},
        );

        $PosCounter++;
    }

    return 1;
}

1;
