# --
# Copyright (C) 2017 - 2022 Perl-Services.de, https://www.perl-services.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Ticket::Event::CreateChecklistItemsForChildTickets;

use strict;
use warnings;

use List::Util qw(first);

our @ObjectDependencies = qw(
    Kernel::Config
    Kernel::System::Log
    Kernel::System::DB
    Kernel::System::Time
    Kernel::System::DynamicField
    Kernel::System::DynamicField::Backend
    Kernel::System::PerlServices::TicketChecklist
    Kernel::System::Cache
    Kernel::System::Web::Request
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    for my $Needed (qw(Data Event Config UserID)) {
        if ( !$Param{$Needed} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );

            return;
        }
    }

    for my $NeededData (qw(TicketID)) {
        if ( !$Param{Data}->{$NeededData} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $NeededData in Data!",
            );

            return;
        }
    }

    my ($Method) = $Param{Event} =~ m{TicketMasterLink(.*?)ParentChild};
    $Method //= '';

    if ( $Method eq 'Add' ) {
        $Self->_Add( %Param );
    }
    elsif ( $Method eq 'Delete' ) {
        $Self->_Delete( %Param );
    }

    return 1;
}

sub _Add {
    my ($Self, %Param) = @_;

    my $DBObject           = $Kernel::OM->Get('Kernel::System::DB');
    my $LogObject          = $Kernel::OM->Get('Kernel::System::Log');
    my $TimeObject         = $Kernel::OM->Get('Kernel::System::Time');
    my $TicketObject       = $Kernel::OM->Get('Kernel::System::Ticket');
    my $CacheObject        = $Kernel::OM->Get('Kernel::System::Cache');
    my $ParamObject        = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $ConfigObject       = $Kernel::OM->Get('Kernel::Config');
    my $DynamicFieldObject = $Kernel::OM->Get('Kernel::System::DynamicField');
    my $BackendObject      = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');
    my $ChecklistObject    = $Kernel::OM->Get('Kernel::System::PerlServices::TicketChecklist');
    my $StatusObject       = $Kernel::OM->Get('Kernel::System::PerlServices::TicketChecklistStatus');

    # get recently added links (within last 20 seconds
    my $SystemTime = $TimeObject->SystemTime() - 20;
    my $TimeStamp  = $TimeObject->SystemTime2TimeStamp( SystemTime => $SystemTime );
    my $SQL        = qq~
        SELECT target_key
        FROM link_relation
        WHERE create_time > ?
            AND source_key = ?
            AND source_object_id = (
                SELECT id
                FROM link_object
                WHERE name = 'Ticket'
            )
            AND type_id IN (
                SELECT id
                FROM link_type
                WHERE name = 'ParentChild'
            )
            AND target_object_id = (
                SELECT id
                FROM link_object
                WHERE name = 'Ticket'
            )
    ~;

    return if !$DBObject->Prepare(
        SQL  => $SQL,
        Bind => [ \$TimeStamp, \$Param{Data}->{TicketID} ],
    );

    my @TicketIDs;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        push @TicketIDs, $Row[0];
    }

    my $CheckSQL = qq~
        SELECT id
        FROM ps_ticketchecklist
        WHERE foreign_ticket_id = ?
            AND ticket_id = ?
    ~;

    my $Mapping  = $ConfigObject->Get('TicketChecklist::TicketStateToItemState') || {};

    TICKETID:
    for my $TicketID ( @TicketIDs ) {
        next TICKETID if !$DBObject->Prepare(
            SQL   => $CheckSQL,
            Bind  => [ \$TicketID, \$Param{Data}->{TicketID} ],
            Linit => 1,
        );

        my $ID;
        while ( my @Row = $DBObject->FetchrowArray() ) {
            $ID = $Row[0];
        }

        next TICKETID if $ID;

        my %Ticket = $TicketObject->TicketGet(
            TicketID => $TicketID,
            UserID   => 1,
        );

        my @Checklist = $ChecklistObject->TicketChecklistTicketGet(
            TicketID  => $Param{Data}->{TicketID},
            UserID    => $Param{UserID},
        );

        if ( !@Checklist ) {
            $ChecklistObject->TicketChecklistCreate(
                TicketID  => $Param{Data}->{TicketID},
                UserID    => $Param{UserID},
            );
        }

        my $NewState = $Mapping->{ $Ticket{State} };
        my $State    = 1;

        if ( $NewState ) {
             my $NewStateID = $StatusObject->TicketChecklistStatusLookup( Name => $NewState );
             $State         = $NewStateID if $NewStateID;
        }

        my $Position = scalar @Checklist;

        $ChecklistObject->TicketChecklistAdd(
            Title           => $Ticket{Title},
# TODO: use generic user as responsible
            ResponsibleID   => $Ticket{OwnerID},
            ResponsibleKey  => $Ticket{OwnerID},
            StatusID        => $State,
            PriorityID      => $Ticket{PriorityID},
            Position        => $Position+1,
            TicketID        => $Param{Data}->{TicketID},
            ForeignTicketID => $TicketID,
            UserID          => $Param{UserID},
        );
    }

    return 1;
}

sub _Delete {
    my ($Self, %Param) = @_;

    return 1;
}

1;
