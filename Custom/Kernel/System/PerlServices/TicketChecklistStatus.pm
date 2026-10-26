# --
# Kernel/System/PerlServices/TicketChecklistStatus.pm - All ticket checklist item status related functions should be here eventually
# Copyright (C) 2014 - 2022 Perl-Services.de, https://www.perl-services.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::PerlServices::TicketChecklistStatus;

use strict;
use warnings;

our @ObjectDependencies = qw(
    Kernel::System::User
    Kernel::System::Valid
    Kernel::System::Log
    Kernel::System::DB
);

=head1 NAME

Kernel::System::PerlServices::TicketChecklistStatus - ...

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

    return $Self;
}

=item TicketChecklistStatusAdd()

Add status

    my $ID = $TicketChecklistStatusObject->TicketChecklistStatusAdd(
        Name    => 'Ticket',
        Color   => 1235,
        ValidID => 1,
        UserID  => 123,
    );

=cut

sub TicketChecklistStatusAdd {
    my ( $Self, %Param ) = @_;

    my $LogObject  = $Kernel::OM->Get('Kernel::System::Log');
    my $DBObject   = $Kernel::OM->Get('Kernel::System::DB');
    my $JSONObject = $Kernel::OM->Get('Kernel::System::JSON');

    # check needed stuff
    for my $Needed (qw(Name Color ValidID UserID)) {
        if ( !$Param{$Needed} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
            return;
        }
    }

    my $CheckID = $Self->TicketChecklistStatusLookup(
        Name => $Param{Name},
    );

    if ( $CheckID ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "State name alread in use",
        );

        return;
    }

    my @Queues     = map{ "q$_" }@{ $Param{Queues} || [] };
    my $QueuesJSON = $JSONObject->Encode( Data => \@Queues );

    my @Roles     = map{ "q$_" }@{ $Param{Roles} || [] };
    my $RolesJSON = $JSONObject->Encode( Data => \@Roles );

    # insert state
    return if !$DBObject->Do(
        SQL => 'INSERT INTO ps_ticketchecklist_status '
            . '(name, color, valid_id, create_time, create_by, change_time, change_by, queues, roles) '
            . 'VALUES (?, ?, ?, current_timestamp, ?, current_timestamp, ?, ?, ?)',
        Bind => [
            \$Param{Name},
            \$Param{Color},
            \$Param{ValidID},
            \$Param{UserID},
            \$Param{UserID},
            \$QueuesJSON,
            \$RolesJSON,
        ],
    );

    my $ID = $Self->TicketChecklistStatusLookup(
        Name => $Param{Name},
    );

    # log notice
    $LogObject->Log(
        Priority => 'notice',
        Message  => "TicketChecklistStatus '$ID' created successfully ($Param{UserID})!",
    );

    return $ID;
}


=item TicketChecklistStatusUpdate()

to update state 

    my $Success = $TicketChecklistStatusObject->TicketChecklistStatusUpdate(
        ID            => 3,
        Name         => 1984756823,
        Color          => 1984756823,
        ValidID       => 1,
        AgentID       => 15,
        UserID        => 123,
    );

=cut

sub TicketChecklistStatusUpdate {
    my ( $Self, %Param ) = @_;

    my $LogObject  = $Kernel::OM->Get('Kernel::System::Log');
    my $DBObject   = $Kernel::OM->Get('Kernel::System::DB');
    my $JSONObject = $Kernel::OM->Get('Kernel::System::JSON');

    # check needed stuff
    for my $Needed (qw(ID Name Color ValidID UserID)) {
        if ( !$Param{$Needed} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
            return;
        }
    }

    my $CheckID = $Self->TicketChecklistStatusLookup(
        Name => $Param{Name},
    );

    if ( $CheckID && $CheckID != $Param{ID} ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "State name alread in use",
        );
    }

    my @Queues     = map{ "q$_" }@{ $Param{Queues} || [] };
    my $QueuesJSON = $JSONObject->Encode( Data => \@Queues );

    my @Roles     = map{ "r$_" }@{ $Param{Roles} || [] };
    my $RolesJSON = $JSONObject->Encode( Data => \@Roles );

    # update state
    return if !$DBObject->Do(
        SQL => 'UPDATE ps_ticketchecklist_status SET '
            . ' name = ?, color = ?, valid_id = ?, change_time = current_timestamp, change_by = ?, '
            . ' queues = ?, roles = ? '
            . ' WHERE id = ?',
        Bind => [
            \$Param{Name},
            \$Param{Color},
            \$Param{ValidID},
            \$Param{UserID},
            \$QueuesJSON,
            \$RolesJSON,
            \$Param{ID},
        ],
    );

    return 1;
}

=item TicketChecklistStatusGet()

returns a hash with status data

    my %TicketChecklistStatusData = $TicketChecklistStatusObject->TicketChecklistStatusGet( ID => 2 );

This returns something like:

    %TicketChecklistStatusData = (
        ID         => 3,
        Name       => 'closed',
        Color      => 'gray',
        ValidID    => 1,
        CreateBy   => 354,
        CreateTime => '',
        ChangeBy   => 35,
        ChangeTime => '',
    );

=cut

sub TicketChecklistStatusGet {
    my ( $Self, %Param ) = @_;

    my $LogObject   = $Kernel::OM->Get('Kernel::System::Log');
    my $DBObject    = $Kernel::OM->Get('Kernel::System::DB');
    my $ValidObject = $Kernel::OM->Get('Kernel::System::Valid');
    my $UserObject  = $Kernel::OM->Get('Kernel::System::User');
    my $JSONObject  = $Kernel::OM->Get('Kernel::System::JSON');

    # check needed stuff
    if ( !$Param{ID} ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'Need ID!',
        );
        return;
    }

    # sql
    return if !$DBObject->Prepare(
        SQL => 'SELECT id, name, color, valid_id, create_by, create_time, change_by, change_time, '
            . 'queues, roles '
            . 'FROM ps_ticketchecklist_status WHERE id = ?',
        Bind  => [ \$Param{ID} ],
        Limit => 1,
    );

    my %TicketChecklistStatus;
    while ( my @Data = $DBObject->FetchrowArray() ) {
        %TicketChecklistStatus = (
            ID         => $Data[0],
            Name       => $Data[1],
            Color      => $Data[2],
            ValidID    => $Data[3],
            CreateBy   => $Data[4],
            CreateTime => $Data[5],
            ChangeBy   => $Data[6],
            ChangeTime => $Data[7],
            Queues     => $Data[8],
            Roles      => $Data[9],
        );
    }

    my @QueueList = map{
        substr $_, 1
    } @{ $JSONObject->Decode( Data => $TicketChecklistStatus{Queues} || '[]' ) };

    my @RoleList = map{
        substr $_, 1
    } @{ $JSONObject->Decode( Data => $TicketChecklistStatus{Roles} || '[]' ) };

    $TicketChecklistStatus{Valid}   = $ValidObject->ValidLookup( ValidID => $TicketChecklistStatus{ValidID} );
    $TicketChecklistStatus{Creator} = $UserObject->UserLookup( UserID => $TicketChecklistStatus{CreateBy} );
    $TicketChecklistStatus{Queues}  = \@QueueList;
    $TicketChecklistStatus{Roles}   = \@RoleList;

    return %TicketChecklistStatus;
}

=item TicketChecklistStatusDelete()

deletes a status entry. Returns 1 if it was successful, undef otherwise.

    my $Success = $TicketChecklistStatusObject->TicketChecklistStatusDelete(
        ID => 123,
    );

=cut

sub TicketChecklistStatusDelete {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');
    my $DBObject  = $Kernel::OM->Get('Kernel::System::DB');

    # check needed stuff
    if ( !$Param{ID} ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'Need ID!',
        );
        return;
    }

    return $DBObject->Do(
        SQL  => 'DELETE FROM ps_ticketchecklist_status WHERE id = ?',
        Bind => [ \$Param{ID} ],
    );
}

=item TicketChecklistStatusList()

=cut

sub TicketChecklistStatusList {
    my ($Self, %Param) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');
    my $DBObject  = $Kernel::OM->Get('Kernel::System::DB');

    my $SQL = 'SELECT id, name FROM ps_ticketchecklist_status';

    $Param{Valid} //= 1;

    my @Bind;
    my @Where;
    if ( $Param{Valid} ) {
        push @Where, ' valid_id = ?';
        push @Bind, \1;
    }

    if ( $Param{Queues} ) {
        my $QueuesCond = '';
        for my $Queue ( @{ $Param{Queues} } ) {
            $QueuesCond .= sprintf q~ OR queues LIKE ?~;
            my $QueueParam = sprintf q~%%"q%s"%%~, $Queue;
            push @Bind, \$QueueParam;
        }

        my $QueuesWhere = sprintf q~(
            queues = '[]' OR queues IS NULL
            %s
        )~, $QueuesCond;

        push @Where, $QueuesWhere;
    }

    if ( $Param{Roles} ) {
        my $RolesCond = '';
        for my $Role ( @{ $Param{Roles} } ) {
            $RolesCond .= sprintf q~ OR roles LIKE ?~;
            my $RoleParam = sprintf q~%%"r%s"%%~, $Role;
            push @Bind, \$RoleParam;
        }

        my $RolesWhere = sprintf q~(
            roles = '[]' OR roles IS NULL
            %s
        )~, $RolesCond;

        push @Where, $RolesWhere;
    }

    my $Where = join ' AND ', @Where;
    $SQL .= ' WHERE ' . $Where if $Where;

    return if !$DBObject->Prepare(
        SQL  => $SQL,
        Bind => \@Bind,
    );

    my %StatusList;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $StatusList{ $Row[0] } = $Row[1];
    }

    return %StatusList;
}

=item TicketChecklistStatusLookup()

    my $Name = $TicketChecklistStatusObject->TicketChecklistStatusLookup(
        ID => 123,
    );

or

    my $ID = $TicketChecklistStatusObject->TicketChecklistStatusLookup(
        Name => 123,
    );

=cut

sub TicketChecklistStatusLookup {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');
    my $DBObject  = $Kernel::OM->Get('Kernel::System::DB');

    # check needed stuff
    if ( !$Param{ID} && !$Param{Name}) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'Need either ID or Name!',
        );
        return;
    }

    my $SQL  = 'SELECT id FROM ps_ticketchecklist_status WHERE name = ?';
    my $Bind = [ \$Param{Name} ];

    if ( $Param{ID} ) {
        $SQL  = 'SELECT name FROM ps_ticketchecklist_status WHERE id = ?';
        $Bind = [ \$Param{ID} ];
    }

    return if !$DBObject->Prepare(
        SQL   => $SQL,
        Bind  => $Bind,
        Limit => 1,
    );

    my $Value;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $Value = $Row[0];
    }

    return $Value;
}

1;

=back

=head1 TERMS AND CONDITIONS

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (AGPL). If you
did not receive this file, see L<http://www.gnu.org/licenses/agpl.txt>.

=cut

