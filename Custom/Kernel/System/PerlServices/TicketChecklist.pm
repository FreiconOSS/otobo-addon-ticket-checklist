# --
# Copyright (C) 2014 - 2022 Perl-Services.de, https://www.perl-services.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::PerlServices::TicketChecklist;

use strict;
use warnings;

our @ObjectDependencies = qw(
    Kernel::System::Log
    Kernel::System::DB
    Kernel::System::Time
    Kernel::System::User
    Kernel::System::Valid
    Kernel::System::Ticket
    Kernel::System::PerlServices::TicketChecklistStatus
);

use Kernel::System::EventHandler;

our @ISA = (
    'Kernel::System::EventHandler',
);

=head1 NAME

Kernel::System::PerlServices::TicketChecklist - backend for ticket checklists

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
        Config     => 'TicketChecklist::EventModule',
        BaseObject => $Self,
        Objects    => {
            %{$Self},
        },
    );

    return $Self;
}

=item TicketChecklistCreate()

This is just a dummy method that triggers the TicketChecklistCreate event

Every module that adds checklist items have to call this method before the first checklist item is added - when no checklist exists.

=cut

sub TicketChecklistCreate {
    my ($Self, %Param) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    # check needed stuff
    for my $Needed ( qw(TicketID UserID) ) {
        if ( !$Param{$Needed} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
            return;
        }
    }

    $Self->EventHandler(
        Event => 'TicketChecklistCreate',
        Data  => {
            TicketID => $Param{TicketID},
        },
        UserID => $Param{UserID},
    );

    return 1;
}

=item TicketChecklistRemove()

This is just a dummy method that triggers the TicketChecklistRemove event

Every module that adds checklist items have to call this method before the first checklist item is added - when no checklist exists.

=cut

sub TicketChecklistRemove {
    my ($Self, %Param) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    # check needed stuff
    for my $Needed ( qw(TicketID UserID) ) {
        if ( !$Param{$Needed} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
            return;
        }
    }

    $Self->EventHandler(
        Event => 'TicketChecklistRemove',
        Data  => {
            TicketID => $Param{TicketID},
        },
        UserID => $Param{UserID},
    );

    return 1;
}

=item TicketChecklistAdd()

Add time tracking 

    my $ID = $TicketChecklistObject->TicketChecklistAdd(
        TicketID => 1235,
        Title    => 'tracking title',
        Status   => 'open',  # or StatusID => 1,
        UserID   => 123,
    );

=cut

sub TicketChecklistAdd {
    my ( $Self, %Param ) = @_;

    my $LogObject    = $Kernel::OM->Get('Kernel::System::Log');
    my $DBObject     = $Kernel::OM->Get('Kernel::System::DB');
    my $StatusObject = $Kernel::OM->Get('Kernel::System::PerlServices::TicketChecklistStatus');
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');


    # check needed stuff
    for my $Needed ( qw(TicketID Title UserID Position) ) {
        if ( !$Param{$Needed} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
            return;
        }
    }

    if ( !$Param{Status} && !$Param{StatusID} ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'Need either Status or StatusID',
        );

        return;
    }

    if ( $Param{Status} ) {
        $Param{StatusID} = $StatusObject->TicketChecklistStatusLookup( Name => $Param{Status} );
    }

    my $Status = $StatusObject->TicketChecklistStatusLookup( ID => $Param{StatusID} );
    if ( !defined $Status ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'Cannot find Status for ID ' . $Param{StatusID},
        );

        return;
    }

    $Param{ResponsibleID}   ||= 0; # TODO: Use "-1" if SysConfig-Setting is activated?
    $Param{PriorityID}      ||= 0;
    $Param{ArticleID}       ||= 0;
    $Param{ArticleNumber}   ||= 0;
    $Param{ForeignTicketID} ||= 0;

    my $UseAutocomplete = $ConfigObject->Get('TicketChecklist::ResponsibleAutocomplete') ? 1 : 0;
    if ( $UseAutocomplete ) {
        $Param{ResponsibleID} = 0;
    }

    my $ChangeNote = $Param{ChangeNote};
    if ( !$ConfigObject->Get('TicketChecklist::SaveChangeNote') ) {
        $ChangeNote = '';
    }

    # insert new item
    return if !$DBObject->Do(
        SQL => 'INSERT INTO ps_ticketchecklist '
            . '(title, position, status_id, ticket_id, priority_id, responsible_id, due_date, '
            . ' article_id, article_number, comments, responsible_key, change_notes, '
            . ' foreign_ticket_id, date_start, '
            . ' create_time, create_by, change_time, change_by, state_change_by) '
            . 'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, current_timestamp, ?, current_timestamp, ?, ?)',
        Bind => [
            \$Param{Title},
            \$Param{Position},
            \$Param{StatusID},
            \$Param{TicketID},
            \$Param{PriorityID},
            \$Param{ResponsibleID},
            \$Param{DueDate},
            \$Param{ArticleID},
            \$Param{ArticleNumber},
            \$Param{Comment},
            \$Param{ResponsibleKey},
            \$ChangeNote,
            \$Param{ForeignTicketID},
            \$Param{DateStart},
            \$Param{UserID},
            \$Param{UserID},
            \0,
        ],
    );

    # get new item id
    return if !$DBObject->Prepare(
        SQL   => 'SELECT MAX(id) FROM ps_ticketchecklist WHERE position = ? AND ticket_id = ?',
        Bind  => [ \$Param{Position}, \$Param{TicketID} ],
        Limit => 1,
    );

    my $ID;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $ID = $Row[0];
    }

    # log notice
    $LogObject->Log(
        Priority => 'notice',
        Message  => "TicketChecklist item '$ID' created successfully ($Param{UserID})!",
    );

    $Self->EventHandler(
        Event => 'ItemAdd',
        Data  => {
            ItemID => $ID,
        },
        UserID => $Param{UserID},
    );

    if ( $Param{ResponsibleID} || $Param{ResponsibleKey} ) {
        $Self->EventHandler(
            Event => 'ItemResponsibleUpdate',
            Data  => {
                ItemID         => $ID,
                Responsible    => $Param{ResponsibleID},
                ResponsibleKey => $Param{ResponsibleKey},
            },
            UserID => $Param{UserID},
        );
    }

    if ( $Param{DueDate} ) {
        $Self->EventHandler(
            Event => 'ItemDueDateUpdate',
            Data  => {
                ItemID => $ID,
            },
            UserID => $Param{UserID},
        );
    }

    if ( $Param{DateStart} ) {
        $Self->EventHandler(
            Event => 'ItemDateStartUpdate',
            Data  => {
                ItemID => $ID,
            },
            UserID => $Param{UserID},
        );
    }

    if ( $Param{ChangeNote} ) {
        $Self->EventHandler(
            Event => 'ItemChangeNote',
            Data  => {
                ItemID     => $ID,
                TicketID   => $Param{TicketID},
                ChangeNote => $Param{ChangeNote},
            },
            UserID => $Param{UserID},
        );
    }

    return $ID;
}


=item TicketChecklistUpdate()

to update news 

    my $Success = $TicketChecklistObject->TicketChecklistUpdate(
        ID       => 3,
        TicketID => 1235,
        Title    => 'tracking title', # (optional)
        Status   => 'open',  # or StatusID => 1,
    );

=cut

sub TicketChecklistUpdate {
    my ( $Self, %Param ) = @_;

    my $LogObject    = $Kernel::OM->Get('Kernel::System::Log');
    my $DBObject     = $Kernel::OM->Get('Kernel::System::DB');
    my $StatusObject = $Kernel::OM->Get('Kernel::System::PerlServices::TicketChecklistStatus');
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    # check needed stuff
    for my $Needed (qw(ID TicketID Title UserID)) {
        if ( !$Param{$Needed} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
            return;
        }
    }

    if ( !$Param{Status} && !$Param{StatusID} ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'Need either Status or StatusID',
        );

        return;
    }

    if ( $Param{Status} ) {
        $Param{StatusID} = $StatusObject->TicketChecklistStatusLookup( Name => $Param{Status} );
    }

    my %Item = $Self->TicketChecklistGet(
        ID => $Param{ID},
    );

    $Param{ResponsibleID}   ||= 0; # TODO: Use "-1" if SysConfig-Setting is activated?
    $Param{PriorityID}      ||= 0;
    $Param{ArticleID}       ||= 0;
    $Param{ArticleNumber}   ||= 0;
    $Param{ForeignTicketID} ||= 0;
    $Param{WorkflowUserID}  //= $Param{UserID};

    my $UseAutocomplete = $ConfigObject->Get('TicketChecklist::ResponsibleAutocomplete') ? 1 : 0;
    if ( $UseAutocomplete ) {
        $Param{ResponsibleID} = 0;
    }

    my $ChangeNote = $Item{ChangeNote} // '';
    if ( defined $Param{ChangeNote} && $Param{ChangeNote} ne '' && !$Param{Override} ) {
        $ChangeNote .= "\n\n" if $ChangeNote;
        $ChangeNote .= $Param{ChangeNote};
    }
    elsif ( $Param{Override} ) {
        $ChangeNote = $Param{ChangeNote};
    }

    if ( !$ConfigObject->Get('TicketChecklist::SaveChangeNote') ) {
        $ChangeNote = $Item{ChangeNote} // '';
    }

    my $StateChangeByCol = "";
    my @Bind;
    if ( $Param{StatusID} != $Item{StatusID} ) {
        $StateChangeByCol = ", state_change_by = ?";
        push @Bind, \$Param{WorkflowUserID};
    }

    # insert new news
    return if !$DBObject->Do(
        SQL => 'UPDATE ps_ticketchecklist SET '
            . ' title = ?, position = ?, status_id = ?, ticket_id = ?, '
            . ' priority_id = ?, responsible_id = ?, due_date = ?, '
            . ' change_time = current_timestamp, change_by = ?, comments = ?, '
            . ' article_id = ?, article_number = ?, responsible_key = ?, '
            . ' change_notes = ?, foreign_ticket_id = ? ' . $StateChangeByCol . ', '
            . ' date_start = ? '
            . ' WHERE id = ?',
        Bind => [
            \$Param{Title},
            \$Param{Position},
            \$Param{StatusID},
            \$Param{TicketID},
            \$Param{PriorityID},
            \$Param{ResponsibleID},
            \$Param{DueDate},
            \$Param{UserID},
            \$Param{Comment},
            \$Param{ArticleID},
            \$Param{ArticleNumber},
            \$Param{ResponsibleKey},
            \$ChangeNote,
            \$Param{ForeignTicketID},
            @Bind,
            \$Param{DateStart},
            \$Param{ID},
        ],
    );

    $Self->EventHandler(
        Event => 'ItemUpdate',
        Data  => {
            ItemID => $Param{ID},
        },
        UserID => $Param{UserID},
    );

    if ( $Param{TicketID} != $Item{TicketID} ) {
        $Self->EventHandler(
            Event => 'ItemMove',
            Data  => {
                ItemID      => $Param{ID},
                OldTicketID => $Item{TicketID},
                NewTicketID => $Param{TicketID},
            },
            UserID => $Param{UserID},
        );
    }

    if (
        ( $Param{ResponsibleID} && !$Item{ResponsibleID} ) ||
        ( $Param{ResponsibleID} && ( $Param{ResponsibleID} ne $Item{ResponsibleID} ) ) ||
        ( $Param{ResponsibleKey} && ( $Param{ResponsibleKey} ne $Item{ResponsibleKey} ) )
    ) {
        $Self->EventHandler(
            Event => 'ItemResponsibleUpdate',
            Data  => {
                ItemID         => $Param{ID},
                Responsible    => $Param{ResponsibleID},
                ResponsibleKey => $Param{ResponsibleKey},
            },
            UserID => $Param{UserID},
        );
    }

    if ( $Param{StatusID} != $Item{StatusID} ) {
        $Self->EventHandler(
            Event => 'ItemStatusUpdate',
            Data  => {
                ItemID    => $Param{ID},
                StatusID  => $Param{StatusID},
                OldStatus => $Item{Status},

                NoConditionsActions => $Param{NoConditionsActions},
            },
            UserID => $Param{UserID},
        );

        my $Status     = $StatusObject->TicketChecklistStatusLookup( ID => $Param{StatusID} );
        my $OpenStates = $ConfigObject->Get('TicketChecklist::OpenStates') || [];
        if ( !grep{ $Status eq $_ }@{ $OpenStates } ) {
            my $AllClosed = $Self->_CheckAllItemsClosed(
                TicketID => $Param{TicketID},
            );

            if ( $AllClosed ) {
                $Self->EventHandler(
                    Event => 'ItemsAllClosed',
                    Data  => {
                        ItemID   => $Param{ID},
                        TicketID => $Param{TicketID},
                    },
                    UserID => $Param{UserID},
                );
            }
        }
    }

    $Param{DueDate} //= '';
    $Item{DueDate}  //= '';

    if ( ( $Param{DueDate} && !$Item{DueDate} ) || ( $Param{DueDate} ne $Item{DueDate} ) ) {
        $Self->EventHandler(
            Event => 'ItemDueDateUpdate',
            Data  => {
                ItemID => $Param{ID},
            },
            UserID => $Param{UserID},
        );
    }

    $Param{DateStart} //= '';
    $Item{DateStart}  //= '';

    if ( ( $Param{DateStart} && !$Item{DateStart} ) || ( $Param{DateStart} ne $Item{DateStart} ) ) {
        $Self->EventHandler(
            Event => 'ItemDateStartUpdate',
            Data  => {
                ItemID => $Param{ID},
            },
            UserID => $Param{UserID},
        );
    }

    if ( $Param{ChangeNote} ) {
        $Self->EventHandler(
            Event => 'ItemChangeNote',
            Data  => {
                ItemID            => $Param{ID},
                TicketID          => $Param{TicketID},
                ChangeNote        => $Param{ChangeNote},
                #ChangeNoteChanged => ( $Param{ChangeNote} ne $Item{ChangeNote}),
            },
            UserID => $Param{UserID},
        );
    }

    return 1;
}

=item TicketChecklistGet()

returns a hash with news data

    my %TicketChecklistData = $TicketChecklistObject->TicketChecklistGet( ID => 2 );

This returns something like:

    %TicketChecklistData = (
        ID            => 3,
        TicketID      => 1235,
        Title         => 'tracking title',
        Status        => 'open',
        StatusID      => 1,
        Position      => 1,
        Responsible   => 'Responsible Agent',
        ResponsibleID => 3,
        PriorityID    => 3,
        ArticleID     => 3,
        ArticleNumber => 3,
        Priority      => '3 normal',
        DueDate       => '2014-01-01',
        DateStart     => '2014-01-01',
        Comment       => 'A comment',
        Creator       => 'Agent Name',
        CreateBy      => 354,
        CreateTime    => '',
        ChangeBy      => 35,
        ChangeTime    => '',
    );

=cut

sub TicketChecklistGet {
    my ( $Self, %Param ) = @_;
 
    my $ConfigObject   = $Kernel::OM->Get('Kernel::Config');
    my $LogObject      = $Kernel::OM->Get('Kernel::System::Log');
    my $DBObject       = $Kernel::OM->Get('Kernel::System::DB');
    my $UserObject     = $Kernel::OM->Get('Kernel::System::User');
    my $StatusObject   = $Kernel::OM->Get('Kernel::System::PerlServices::TicketChecklistStatus');
    my $PriorityObject = $Kernel::OM->Get('Kernel::System::Priority');

    # check needed stuff
    if ( !$Param{ID} ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'Need ID!',
        );
        return;
    }


    return if $Param{ID} == -1;

    # sql
    return if !$DBObject->Prepare(
        SQL => 'SELECT id, title, status_id, position, ticket_id, '
            . '    create_by, create_time, change_by, change_time, '
            . '    priority_id, responsible_id, due_date, comments, '
            . '    article_id, article_number, responsible_key, change_notes, '
            . '    foreign_ticket_id, state_change_by, date_start'
            . ' FROM ps_ticketchecklist WHERE id = ?',
        Bind  => [ \$Param{ID} ],
        Limit => 1,
    );

    my %TicketChecklist;
    while ( my @Data = $DBObject->FetchrowArray() ) {
        %TicketChecklist = (
            ID              => $Data[0],
            Title           => $Data[1],
            StatusID        => $Data[2],
            Position        => $Data[3],
            TicketID        => $Data[4],
            CreateBy        => $Data[5],
            CreateTime      => $Data[6],
            ChangeBy        => $Data[7],
            ChangeTime      => $Data[8],
            PriorityID      => $Data[9],
            ResponsibleID   => $Data[10],
            DueDate         => $Data[11],
            Comment         => $Data[12],
            ArticleID       => $Data[13] || '',
            ArticleNumber   => $Data[14] || '',
            ResponsibleKey  => $Data[15],
            ChangeNote      => $Data[16] // '',
            ForeignTicketID => $Data[17] // '',
            StateChangeby   => $Data[18] // '',
            DateStart       => $Data[19],
        );
    }

    $TicketChecklist{Status} = $StatusObject->TicketChecklistStatusLookup(
        ID => $TicketChecklist{StatusID},
    );

    $TicketChecklist{Creator} = $UserObject->UserLookup( UserID => $TicketChecklist{CreateBy} );

    if ( $TicketChecklist{ResponsibleID} ) {
        my %UserData = $UserObject->GetUserData(
            UserID => $TicketChecklist{ResponsibleID},
        );

        $TicketChecklist{Responsible}         = $UserData{UserLogin};
        $TicketChecklist{ResponsibleFullname} = $UserData{UserFullname};
    }
    else {
        my $UseAutocomplete    = $ConfigObject->Get('TicketChecklist::ResponsibleAutocomplete') ? 1 : 0;
        my $AutocompleteModule = $ConfigObject->Get('TicketChecklist::ResponsibleAutocompleteModule') // 'Agent';

        my $AutocompleteObject = $Kernel::OM->Get(
           'Kernel::System::PerlServices::TicketChecklist::Autocomplete::' . $AutocompleteModule
        );

        $TicketChecklist{Responsible} = $AutocompleteObject->Fullname(
            UserLogin => $TicketChecklist{ResponsibleKey},
        );

        $TicketChecklist{ResponsibleFullname} = $TicketChecklist{Responsible};
    }

    $TicketChecklist{Priority} = $PriorityObject->PriorityLookup(
        PriorityID => $TicketChecklist{PriorityID},
    );

    $TicketChecklist{ResponsibleKey} //= '';

    if ( $TicketChecklist{StateChangeBy} ) {
        $TicketChecklist{StateChangeAgent} = $UserObject->UserLookup(
            UserID => $TicketChecklist{StateChangeBy},
        );
    }

    return %TicketChecklist;
}

=item TicketChecklistDelete()

deletes a checklist item. Returns 1 if it was successful, undef otherwise.

    my $Success = $TicketChecklistObject->TicketChecklistDelete(
        ID => 123,
    );

=cut

sub TicketChecklistDelete {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');
    my $DBObject  = $Kernel::OM->Get('Kernel::System::DB');

    # check needed stuff
    if ( !$Param{ID} && !$Param{TicketID} ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'Need either ID or TicketID!',
        );
        return;
    }

    my $TicketID = $Param{TicketID};
    if ( !$TicketID ) {
        $TicketID = $Self->_TicketIDLookup( ID => $Param{ID} );
    }

    my @Items;
    my $SQL  = 'DELETE FROM ps_ticketchecklist WHERE id = ?';
    my $Bind = \$Param{ID};

    if ( $Param{TicketID} ) {
        $SQL   = 'DELETE FROM ps_ticketchecklist WHERE ticket_id = ?';
        $Bind  = \$Param{TicketID};
        @Items = $Self->TicketChecklistTicketGet( TicketID => $Param{TicketID} );
    }
    else {
        @Items = ( +{ $Self->TicketChecklistGet( ID => $Param{ID} ) } );
    }

    return if !$DBObject->Do(
        SQL  => $SQL,
        Bind => [ $Bind ],
    );

    for my $Item ( @Items ) { 
        $Self->EventHandler(
            Event => 'ItemDelete',
            Data  => {
                Item     => $Item,
                TicketID => $TicketID,
            },
            UserID => $Param{UserID} // 1,
        );
    }

    my $AllClosed = $Self->_CheckAllItemsClosed(
        TicketID => $TicketID,
    );

    if ( $AllClosed ) {
        $Self->EventHandler(
            Event => 'ItemsAllClosed',
            Data  => {
                TicketID => $TicketID,
            },
            UserID => $Param{UserID} // 1,
        );
    }

    return 1;
}

=item TicketChecklistTicketGet()

=cut

sub TicketChecklistTicketGet {
    my ($Self,%Param) = @_;

    my $ConfigObject   = $Kernel::OM->Get('Kernel::Config');
    my $LogObject      = $Kernel::OM->Get('Kernel::System::Log');
    my $DBObject       = $Kernel::OM->Get('Kernel::System::DB');
    my $UserObject     = $Kernel::OM->Get('Kernel::System::User');
    my $PriorityObject = $Kernel::OM->Get('Kernel::System::Priority');
    my $StatusObject   = $Kernel::OM->Get('Kernel::System::PerlServices::TicketChecklistStatus');

    for my $Needed ( qw(TicketID) ) {
        if ( !$Param{$Needed} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );

            return;
        }
    }

    my $SQL = 'SELECT id, title, position, status_id, ticket_id, '
        . '    priority_id, responsible_id, due_date, comments, '
        . '    article_id, article_number, responsible_key, change_notes, '
        . '    state_change_by, date_start'
        . ' FROM ps_ticketchecklist '
        . ' WHERE ticket_id = ? '
        . ' ORDER BY position ASC';

    return if !$DBObject->Prepare(
        SQL  => $SQL,
        Bind => [
            \$Param{TicketID},
        ],
    );

    my @ChecklistItems;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        push @ChecklistItems, {
            ID             => $Row[0],
            Title          => $Row[1],
            Position       => $Row[2],
            StatusID       => $Row[3],
            TicketID       => $Row[4],
            PriorityID     => $Row[5],
            ResponsibleID  => $Row[6],
            DueDate        => $Row[7],
            Comment        => $Row[8],
            ArticleID      => $Row[9]  || '',
            ArticleNumber  => $Row[10] || '',
            ResponsibleKey => $Row[11],
            ChangeNote     => $Row[12] // '',
            StateChangeBy  => $Row[13] // '',
            DateStart      => $Row[14],
        };
    }

    for my $Item ( @ChecklistItems ) {
        my $UseAutocomplete = $ConfigObject->Get('TicketChecklist::ResponsibleAutocomplete') ? 1 : 0;

        if ( $Item->{ResponsibleID} ) {
            my %UserData = $UserObject->GetUserData(
                UserID => $Item->{ResponsibleID},
            );

            $Item->{Responsible}         = $UserData{UserLogin};
            $Item->{ResponsibleFullname} = $UserData{UserFullname};
        }
        elsif ( $UseAutocomplete && $Item->{ResponsibleKey} ) {
            my $AutocompleteModule = $ConfigObject->Get('TicketChecklist::ResponsibleAutocompleteModule') // 'Agent';
    
            my $AutocompleteObject = $Kernel::OM->Get(
               'Kernel::System::PerlServices::TicketChecklist::Autocomplete::' . $AutocompleteModule
            );
    
            $Item->{Responsible} = $AutocompleteObject->Fullname(
                UserLogin => $Item->{ResponsibleKey},
            );
        }

        $Item->{Priority} = $PriorityObject->PriorityLookup(
            PriorityID => $Item->{PriorityID},
        );

        $Item->{Status} = $StatusObject->TicketChecklistStatusLookup(
            ID => $Item->{StatusID},
        );

        if ( $Item->{StateChangeBy} ) {
            $Item->{StateChangeAgent} = $UserObject->UserLookup(
                UserID => $Item->{StateChangeBy},
            );
        }
    }

    return @ChecklistItems;
}

=item TicketChecklistMerge()

=cut

sub TicketChecklistMerge {
    my ($Self, %Param) = @_;

    my $LogObject     = $Kernel::OM->Get('Kernel::System::Log');
    my $DBObject      = $Kernel::OM->Get('Kernel::System::DB');
    my $TicketObject  = $Kernel::OM->Get('Kernel::System::Ticket');
    my $ArticleObject = $Kernel::OM->Get('Kernel::System::Ticket::Article');

    for my $Needed (qw(NewTicketID OldTicketID)) {
        if ( !$Param{$Needed} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );

            return;
        }
    }

    my $SQL = 'UPDATE ps_ticketchecklist '
        . ' SET ticket_id = ?, '
        . ' change_time = current_timestamp, change_by = ? '
        . ' WHERE ticket_id = ?';

    return if !$DBObject->Do(
        SQL  => $SQL,
        Bind => [
            \$Param{NewTicketID},
            \$Param{UserID},
            \$Param{OldTicketID},
        ],
    );

    # recalc article numbers
    my @Items = $Self->TicketChecklistTicketGet(
        TicketID => $Param{NewTicketID},
    );

    my @ArticleBox = $ArticleObject->ArticleList(
        TicketID      => $Param{NewTicketID},
        UserID        => $Param{UserID},
    );

    my %ItemsToUpdate;

    ITEM:
    for my $Item ( @Items ) {
        next ITEM if !$Item->{ArticleID};

        my $ArticleID              = $Item->{ArticleID};
        $ItemsToUpdate{$ArticleID} = $Item->{ID};
    }

    my $ArticleSQL = qq~
        UPDATE ps_ticketchecklist
        SET article_number = ?
        WHERE id = ? AND article_id = ?
    ~;

    my $Counter = 0;

    ARTICLE:
    for my $Article ( @ArticleBox ) {
        $Counter++;

        my $ArticleID = $Article->{ArticleID};

        next ARTICLE if !$ItemsToUpdate{$ArticleID};

        $DBObject->Do(
            SQL  => $ArticleSQL,
            Bind => [ \$Counter, \$ItemsToUpdate{$ArticleID}, \$ArticleID ],
        );
    }

    return 1;
}

sub TicketSearch {
    my ($Self, %Param) = @_;

    return if !$Param{UserID};

    my $DBObject     = $Kernel::OM->Get('Kernel::System::DB');
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $StatusObject = $Kernel::OM->Get('Kernel::System::PerlServices::TicketChecklistStatus');

    $Param{Result} ||= 'ARRAY';

    my @TicketIDs = @{ $Param{TicketIDs} || [] };
    my %TicketIDs;

    if ( !@TicketIDs ) {
        my $SQL = 'SELECT DISTINCT ticket_id '
            . ' FROM ps_ticketchecklist tc '
            . '     INNER JOIN ticket t ON t.id = tc.ticket_id '
            . ' WHERE t.user_id = ? ';

        return if !$DBObject->Prepare(
            SQL  => $SQL,
            Bind => [ \$Param{UserID} ],
        );

        while ( my @Row = $DBObject->FetchrowArray() ) {
            $TicketIDs{ $Row[0] } = 1;
        }

        return if !%TicketIDs;

        @TicketIDs = keys %TicketIDs;
    }

    @TicketIDs{ @TicketIDs } = (1) x @TicketIDs if !%TicketIDs;

    my $TicketIDBind = join ', ', ('?') x @TicketIDs;
    my $OpenStates   = $ConfigObject->Get( 'TicketChecklist::OpenStates' ) || ['open'];
    my %StatusList   = $StatusObject->TicketChecklistStatusList();
    my %ReverseList  = reverse %StatusList;
    my @OpenIDs      = @ReverseList{ @{$OpenStates} };

    if ( $Param{ChecklistStates} ) {
        $Param{ChecklistStateIDs} = [@ReverseList{ @{$Param{ChecklistStates}} }];
    }

    if ( !$Param{Types} && $Param{ChecklistStateIDs} ) {
        @OpenIDs = @{ $Param{ChecklistStateIDs} || [] };
    }

    my $Not          = ( $Param{Types} && lc $Param{Types} eq 'closed' ) ? 1 : 0;
    my $StatusIDBind = join ', ', ('?') x @OpenIDs;

    my $OpenSQL = 'SELECT DISTINCT ticket_id'
        . ' FROM ps_ticketchecklist'
        . " WHERE ticket_id IN ($TicketIDBind)"
        . "     AND status_id IN ($StatusIDBind)";

    return if !$DBObject->Prepare(
        SQL  => $OpenSQL,
        Bind => [ \(@TicketIDs), map{ \$_ }@OpenIDs ],
    );

    my @FoundTicketIDs;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        if ( $Not ) {
            delete $TicketIDs{ $Row[0] };
        }
        else {
            push @FoundTicketIDs, $Row[0];
        }
    }

    if ( $Not ) {
        @FoundTicketIDs = sort keys %TicketIDs;
    }

    return scalar @FoundTicketIDs if $Param{Result} eq 'COUNT';
    return @FoundTicketIDs;
}

sub TaskSearch {
    my ($Self, %Param) = @_;

    return if !$Param{UserID};

    $Param{Return} //= 'Tasks';

    my $DBObject     = $Kernel::OM->Get('Kernel::System::DB');
    my $UserObject   = $Kernel::OM->Get('Kernel::System::User');
    my $MainObject   = $Kernel::OM->Get('Kernel::System::Main');
    my $LogObject    = $Kernel::OM->Get('Kernel::System::Log');
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $StatusObject = $Kernel::OM->Get('Kernel::System::PerlServices::TicketChecklistStatus');

    my $OpenStates   = $ConfigObject->Get( 'TicketChecklist::OpenStates' ) || ['open'];
    my %StatusList   = $StatusObject->TicketChecklistStatusList();
    my @ResponsibleBind;

    my %SortBy = (
        DueDate      => 'tc.due_date',
        DateStart    => 'tc.date_start',
        Priority     => 'tc.priority_id',
        TicketNumber => 't.tn',
        Title        => 'tc.title',
        Status       => 's.name',
        ChangeAgent  => 'u.login',
    );

    my %OrderBy = ( Down => 'ASC', Up => 'DESC' );

    my $SortByString = 'tc.due_date ASC, tc.priority_id DESC';

    if ( $Param{SortBy} && $SortBy{ $Param{SortBy} } ) {
        $SortByString = $SortBy{ $Param{SortBy} };
    }

    if ( $Param{OrderBy} && $OrderBy{ $Param{OrderBy} } ) {
        $SortByString .= " " . $OrderBy{ $Param{OrderBy} };
    }

    my $UseAutocomplete    = $ConfigObject->Get('TicketChecklist::ResponsibleAutocomplete');
    my $AutocompleteModule = $ConfigObject->Get('TicketChecklist::ResponsibleAutocompleteModule') // 'Agent';

    my @PossibleValues = $Param{UserID};

    if ( $UseAutocomplete ) {
        my %UserData = $UserObject->GetUserData( UserID => $Param{UserID} );
        my $AutocompleteObject = $Kernel::OM->Get(
           'Kernel::System::PerlServices::TicketChecklist::Autocomplete::' . $AutocompleteModule
        );

        @PossibleValues = $AutocompleteObject->MemberOfList(
            %UserData,
        );
    }

    push @ResponsibleBind, map{ \$_ }@PossibleValues;

    my $ResponsibleKeyPlaceholder = join ', ', ('?') x @PossibleValues;
    my $ResponsibleKeyClause      = "";

    if ( $ResponsibleKeyPlaceholder ) {
        $ResponsibleKeyClause = sprintf " OR tc.responsible_key IN(%s) ", $ResponsibleKeyPlaceholder;
    }

    my %ReverseList  = reverse %StatusList;
    my @OpenIDs      = @ReverseList{ @{$OpenStates} };
    my $Not          = ( $Param{Types} && lc $Param{Types} eq 'closed' ) ? ' NOT ' : '';
    my $StatusIDBind = join ', ', ('?') x @OpenIDs;

    my @Filters;
    my @FilterBinds;

    my %WhereColumns = (
        PriorityIDs      => 'tc.priority_id',
        StatusIDs        => 'tc.status_id',
        TicketIDs        => 't.id',
        ForeignTicketIDs => 'tc.foreign_ticket_id',
        ChangeAgentIDs   => 'tc.state_change_by',
    );

    my $HasFilter;
    for my $Column (sort keys %WhereColumns) {
        if ( $Param{$Column} && ref $Param{$Column} eq 'ARRAY' ) {
            push @Filters, sprintf ' %s IN(%s) ',
                $WhereColumns{$Column}, 
                join ', ', ('?') x @{ $Param{$Column} };

            push @FilterBinds, map{ \$_ }@{ $Param{$Column} };
            $HasFilter++;
        }
    }

    if ( !$HasFilter || ( $Param{Types} && lc $Param{Types} eq 'open' ) ) {
        push @FilterBinds, map{ \$_ }@OpenIDs;
        push @Filters, "tc.status_id $Not IN($StatusIDBind)";
    }

    if ( $Param{Start} && $Param{Stop} ) {
        push @Filters, '( tc.due_date >= ? AND tc.due_date <= ? )';
        push @FilterBinds, \$Param{Start}, \$Param{Stop};
    }

    my $Where = join ' AND ', @Filters if @Filters;
    my @Bind  = @FilterBinds           if @FilterBinds;

    my $SQL = 'SELECT tc.id, tc.ticket_id, tc.priority_id, tc.due_date, tc.title, t.title, '
        . '    tc.status_id, s.name, s.color, t.tn, tp.name, tc.comments, tc.responsible_key, '
        . '    tc.responsible_id, tc.foreign_ticket_id, tc.state_change_by, tc.date_start '
        . ' FROM ps_ticketchecklist tc '
        . '     INNER JOIN ps_ticketchecklist_status s ON s.id = tc.status_id '
        . '     INNER JOIN ticket t ON t.id = tc.ticket_id '
        . '     INNER JOIN ticket_priority tp ON tc.priority_id = tp.id '
        . '     LEFT OUTER JOIN users u ON tc.state_change_by = u.id '
        . ' WHERE ( '
        . '     tc.responsible_id = ? '
        .       $ResponsibleKeyClause
        . '     ) '
        . "     AND $Where "
        . ' ORDER BY ' . $SortByString;

    my %Opts;
    $Opts{Limit} = $Param{Limit} if $Param{Limit};

    return if !$DBObject->Prepare(
        SQL  => $SQL,
        Bind => [ \$Param{UserID}, @ResponsibleBind, @Bind ],
        %Opts,
    );

    my @Tasks;
    my %TicketIDs;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        push @Tasks, +{
            ID              => $Row[0],
            TicketID        => $Row[1],
            PriorityID      => $Row[2],
            DueDate         => $Row[3],
            Title           => $Row[4],
            TicketTitle     => $Row[5],
            StatusID        => $Row[6],
            Status          => $Row[7],
            Color           => $Row[8],
            TicketNumber    => $Row[9],
            Priority        => $Row[10],
            Comment         => $Row[11],
            ResponsibleKey  => $Row[12],
            ResponsibleID   => $Row[13],
            ForeignTicketID => $Row[14],
            StateChangeBy   => $Row[15] // '',
            DateStart       => $Row[16],
        };

        $TicketIDs{ $Row[1] }++;
    }

    for my $Item ( @Tasks ) {
        my $UseAutocomplete = $ConfigObject->Get('TicketChecklist::ResponsibleAutocomplete') ? 1 : 0;

        if ( $Item->{ResponsibleID} ) {
            $Item->{Responsible} = $UserObject->UserLookup(
                UserID => $Item->{ResponsibleID},
            );
        }
        elsif ( $UseAutocomplete && $Item->{ResponsibleKey} ) {
            my $AutocompleteModule = $ConfigObject->Get('TicketChecklist::ResponsibleAutocompleteModule') // 'Agent';

            my $AutocompleteObject = $Kernel::OM->Get(
               'Kernel::System::PerlServices::TicketChecklist::Autocomplete::' . $AutocompleteModule
            );

            $Item->{Responsible} = $AutocompleteObject->Fullname(
                UserLogin => $Item->{ResponsibleKey},
            );
        }

        if ( $Item->{StateChangeBy} && $Param{ResolveAgent} ) {
            $Item->{StateChangeAgent} = $UserObject->UserLookup(
                UserID => $Item->{StateChangeBy},
            );
        }
    }

    if ( $Param{Return} eq 'TicketIDs' ) {
        return sort keys %TicketIDs;
    }

    return @Tasks;
}

sub ItemListForForeignTicketID {
    my ($Self, %Param) = @_;

    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    my $SQL = 'SELECT id FROM ps_ticketchecklist WHERE foreign_ticket_id = ?';

    return if !$DBObject->Prepare(
        SQL  => $SQL,
        Bind => [ \$Param{ID} ],
    );

    my @Tasks;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        push @Tasks, $Row[0];
    }

    return @Tasks;
}

sub DueDateItems {
    my ($Self, %Param) = @_;

    my $DBObject     = $Kernel::OM->Get('Kernel::System::DB');
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $StatusObject = $Kernel::OM->Get('Kernel::System::PerlServices::TicketChecklistStatus');
    my $TimeObject   = $Kernel::OM->Get('Kernel::System::Time');

    my $OpenStates   = $ConfigObject->Get( 'TicketChecklist::OpenStates' ) || ['open'];
    my %StatusList   = $StatusObject->TicketChecklistStatusList();
    my %ReverseList  = reverse %StatusList;
    my @OpenIDs      = @ReverseList{ @{$OpenStates} };
    my $StatusIDBind = join ', ', ('?') x @OpenIDs;
    my $TimeDiff     = ( $ConfigObject->Get( 'TicketChecklist::DueDateBefore' ) || 60 ) * 60;

    my $SystemTime   = $TimeObject->SystemTime();
    my $Start        = $TimeObject->SystemTime2TimeStamp(
        SystemTime => $SystemTime,
    );

    my $Stop = $TimeObject->SystemTime2TimeStamp(
        SystemTime => $SystemTime + $TimeDiff,
    );

    my @NotificationTimes = @{ $ConfigObject->Get('TicketChecklist::NotificationTimes') || [] };
    my $TimeSpan          = $ConfigObject->Get('TicketChecklist::NotificationTimesSpan') || 10;
    my @NotificationTimesList;

    TIME:
    for my $Time ( @NotificationTimes ) {
        my ($Direction, $Amount, $Unit) = $Time =~ m{ \A ([+-]) \s* ([0-9]+) \s* ([md]) \z }xms;

        next TIME if !$Amount;

        if ( $Direction eq '+' ) {
            $Amount *= -1;
        }

        my $Factor = 60;
        $Factor   *= 60 * 24 if $Unit eq 'd';

        my $StopEpoche = $SystemTime + ( $Amount * $Factor );

        my $Start        = $TimeObject->SystemTime2TimeStamp(
            SystemTime => $StopEpoche - ( $TimeSpan * 60 ),
        );

        my $Stop = $TimeObject->SystemTime2TimeStamp(
            SystemTime => $StopEpoche,
        );

        push @NotificationTimesList, [ \$Start, \$Stop ];
    }

    my $NotificationTimesFilter = '';
    my @Binds;
    if ( @NotificationTimesList ) {
        $NotificationTimesFilter = join ' OR ', '', map{ "( tc.due_date > ? AND tc.due_date < ? )" }@NotificationTimesList;
        @Binds                   = map{ @{$_} }@NotificationTimesList;
    }

    my $SQL = 'SELECT tc.id '
        . ' FROM ps_ticketchecklist tc '
        . ' WHERE ( '
        . '         ( tc.due_date > ? AND tc.due_date < ? ) '
        . "         $NotificationTimesFilter "
        . '     ) '
        . "     AND tc.status_id IN ($StatusIDBind)";

    return if !$DBObject->Prepare(
        SQL  => $SQL,
        Bind => [ \$Start, \$Stop, @Binds, map{ \$_ }@OpenIDs ],
    );

    my @Tasks;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        push @Tasks, $Row[0];
    }

    return @Tasks;
}

sub DueDateList {
    my ($Self, %Param) = @_;

    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    my $SQL = 'SELECT DISTINCT tc.due_date '
        . ' FROM ps_ticketchecklist tc ';

    my @Bind;
    if ( $Param{UserID} ) {
        $SQL .= ' WHERE ( tc.responsible_id = ? OR tc.responsible_key = ? )';
        push @Bind, \$Param{UserID}, \$Param{UserID};
    }

    return if !$DBObject->Prepare(
        SQL  => $SQL,
        Bind => \@Bind,
    );

    my %DueDates;

    ROW:
    while ( my @Row = $DBObject->FetchrowArray() ) {
        next ROW if !$Row[0];
        $DueDates{ $Row[0] } = $Row[0];
    }

    return %DueDates;
}

sub ChecklistItemStatusSet {
    my ($Self, %Param) = @_;

    my $LogObject    = $Kernel::OM->Get('Kernel::System::Log');
    my $DBObject     = $Kernel::OM->Get('Kernel::System::DB');

    for my $Needed (qw(ID StatusID OldStatusID OldStatus UserID)) {
        if ( !$Param{$Needed} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );

            return;
        }
    }

    my $SQL = 'UPDATE ps_ticketchecklist '
        . ' SET status_id = ?, '
        . ' change_time = current_timestamp, change_by = ? '
        . ' WHERE id = ?';

    return if !$DBObject->Do(
        SQL  => $SQL,
        Bind => [
            \$Param{StatusID},
            \$Param{UserID},
            \$Param{ID},
        ],
    );

    if ( $Param{StatusID} != $Param{OldStatusID} ) {
        $Self->EventHandler(
            Event => 'ItemStatusUpdate',
            Data  => {
                ItemID    => $Param{ID},
                StatusID  => $Param{StatusID},
                OldStatus => $Param{Status},

                NoConditionsActions => $Param{NoConditionsActions},
            },
            UserID => $Param{UserID},
        );
    }

    return 1;
}

sub ChecklistItemLookup {
    my ($Self, %Param) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');
    my $DBObject  = $Kernel::OM->Get('Kernel::System::DB');

    for my $Needed ( qw/Name TicketID/ ) {
        if ( !$Param{$Needed} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );

            return;
        }
    }

    my $SQL = qq~
        SELECT id
        FROM ps_ticketchecklist
        WHERE title = ?
            AND ticket_id = ?
    ~;

    return if !$DBObject->Prepare(
        SQL  => $SQL,
        Bind => [ \$Param{Name}, \$Param{TicketID} ],
    );

    my $Counter = 0;
    my $ID;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $ID = $Row[0];
        $Counter++;
    }

    return if $Counter > 1;
    return $ID;
}

sub _CheckAllItemsClosed {
    my ($Self, %Param) = @_;

    return if !$Param{TicketID};

    my $DBObject     = $Kernel::OM->Get('Kernel::System::DB');
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    my @OpenStates = @{ $ConfigObject->Get('TicketChecklist::OpenStates') || [] };

    return if !@OpenStates;

    my @Bind        = map{ \$_ }@OpenStates;
    my $Placeholder = join ', ', ('?') x @OpenStates;
    
    my $SQL = qq~
        SELECT tc.id
        FROM ps_ticketchecklist tc 
            INNER JOIN ps_ticketchecklist_status tcs
                ON tcs.id = tc.status_id
        WHERE tc.ticket_id = ?
            AND tcs.name IN ($Placeholder)
    ~;

    return if !$DBObject->Prepare(
        SQL  => $SQL,
        Bind => [ \$Param{TicketID}, @Bind ],
    );

    my $Count = 0;

    ROW:
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $Count++;
    }

    return 0 if $Count;
    return 1;
}

sub _TicketIDLookup {
    my ($Self, %Param) = @_;

    return if !$Param{ID};

    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    my $SQL = 'SELECT ticket_id FROM ps_ticketchecklist WHERE id = ?';
    return if !$DBObject->Prepare(
        SQL  => $SQL,
        Bind => [ \$Param{ID} ],
    );

    my $ID;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $ID = $Row[0];
    }

    return $ID;
}

sub StartedItems {
    my ($Self, %Param) = @_;

    my $DBObject     = $Kernel::OM->Get('Kernel::System::DB');
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $StatusObject = $Kernel::OM->Get('Kernel::System::PerlServices::TicketChecklistStatus');
    my $TimeObject   = $Kernel::OM->Get('Kernel::System::Time');

    my $WaitingStates = $ConfigObject->Get( 'TicketChecklist::WaitingStates' ) || ['waiting'];
    my %StatusList    = $StatusObject->TicketChecklistStatusList();
    my %ReverseList   = reverse %StatusList;
    my @WaitingIDs    = @ReverseList{ @{$WaitingStates} };
    my $StatusIDBind  = join ', ', ('?') x @WaitingIDs;

    my $SystemTime   = $TimeObject->SystemTime();
    my $Start        = $TimeObject->SystemTime2TimeStamp(
        SystemTime => $SystemTime,
    );

    my $SQL = 'SELECT tc.id '
        . ' FROM ps_ticketchecklist tc '
        . ' WHERE '
        . '     tc.date_start < ? '
        . "     AND tc.status_id IN ($StatusIDBind)";

    return if !$DBObject->Prepare(
        SQL  => $SQL,
        Bind => [ \$Start, map{ \$_ }@WaitingIDs ],
    );

    my @Tasks;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        push @Tasks, $Row[0];
    }

    return @Tasks;
}

sub DateStartItems {
    my ($Self, %Param) = @_;

    my $DBObject     = $Kernel::OM->Get('Kernel::System::DB');
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $StatusObject = $Kernel::OM->Get('Kernel::System::PerlServices::TicketChecklistStatus');
    my $TimeObject   = $Kernel::OM->Get('Kernel::System::Time');

    my $OpenStates   = $ConfigObject->Get( 'TicketChecklist::WaitingStates' ) || ['open'];
    my %StatusList   = $StatusObject->TicketChecklistStatusList();
    my %ReverseList  = reverse %StatusList;
    my @OpenIDs      = @ReverseList{ @{$OpenStates} };
    my $StatusIDBind = join ', ', ('?') x @OpenIDs;
    my $TimeDiff     = ( $ConfigObject->Get( 'TicketChecklist::DateStartBefore' ) || 60 ) * 60;

    my $SystemTime   = $TimeObject->SystemTime();
    my $Start        = $TimeObject->SystemTime2TimeStamp(
        SystemTime => $SystemTime,
    );

    my $Stop = $TimeObject->SystemTime2TimeStamp(
        SystemTime => $SystemTime + $TimeDiff,
    );

    my @NotificationTimes = @{ $ConfigObject->Get('TicketChecklist::StartNotificationTimes') || [1] };
    my $TimeSpan          = $ConfigObject->Get('TicketChecklist::StartNotificationTimesSpan') || 10;
    my @NotificationTimesList;

    TIME:
    for my $Time ( @NotificationTimes ) {
        my ($Direction, $Amount, $Unit) = $Time =~ m{ \A ([+-]) \s* ([0-9]+) \s* ([md]) \z }xms;

        next TIME if !$Amount;

        if ( $Direction eq '+' ) {
            $Amount *= -1;
        }

        my $Factor = 60;
        $Factor   *= 60 * 24 if $Unit eq 'd';

        my $StopEpoche = $SystemTime + ( $Amount * $Factor );

        my $Start        = $TimeObject->SystemTime2TimeStamp(
            SystemTime => $StopEpoche - ( $TimeSpan * 60 ),
        );

        my $Stop = $TimeObject->SystemTime2TimeStamp(
            SystemTime => $StopEpoche,
        );

        push @NotificationTimesList, [ \$Start, \$Stop ];
    }

    my $NotificationTimesFilter = '';
    my @Binds;
    if ( @NotificationTimesList ) {
        @Binds                   = map{ @{$_} }@NotificationTimesList;
        $NotificationTimesFilter = join ' OR ', '', map{
            "( tc.date_start > ? AND tc.date_start < ? )"
        } @NotificationTimesList;
    }

    my $SQL = 'SELECT tc.id '
        . ' FROM ps_ticketchecklist tc '
        . ' WHERE ( '
        . '         ( tc.date_start > ? AND tc.date_start < ? ) '
        . "         $NotificationTimesFilter "
        . '     ) '
        . "     AND tc.status_id IN ($StatusIDBind)";

    return if !$DBObject->Prepare(
        SQL  => $SQL,
        Bind => [ \$Start, \$Stop, @Binds, map{ \$_ }@OpenIDs ],
    );

    my @Tasks;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        push @Tasks, $Row[0];
    }

    return @Tasks;
}

sub DateStartList {
    my ($Self, %Param) = @_;

    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    my $SQL = 'SELECT DISTINCT tc.date_start '
        . ' FROM ps_ticketchecklist tc ';

    my @Bind;
    if ( $Param{UserID} ) {
        $SQL .= ' WHERE ( tc.responsible_id = ? OR tc.responsible_key = ? )';
        push @Bind, \$Param{UserID}, \$Param{UserID};
    }

    return if !$DBObject->Prepare(
        SQL  => $SQL,
        Bind => \@Bind,
    );

    my %DateStarts;

    ROW:
    while ( my @Row = $DBObject->FetchrowArray() ) {
        next ROW if !$Row[0];
        $DateStarts{ $Row[0] } = $Row[0];
    }

    return %DateStarts;
}

1;

=back

=head1 TERMS AND CONDITIONS

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (AGPL). If you
did not receive this file, see L<http://www.gnu.org/licenses/agpl.txt>.

=cut

