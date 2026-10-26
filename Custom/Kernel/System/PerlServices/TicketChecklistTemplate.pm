# --
# Kernel/System/PerlServices/TicketChecklistTemplate.pm - All functions related to checklist templates
# Copyright (C) 2015 - 2022 Perl-Services.de, https://www.perl-services.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::PerlServices::TicketChecklistTemplate;

use strict;
use warnings;

our @ObjectDependencies = qw(
    Kernel::System::JSON
    Kernel::System::Valid
);

=head1 NAME

Kernel::System::PerlServices::TicketChecklistTemplate - backend for ticket checklist templates

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

=item TemplateAdd()

Add template

    my $ID = $TemplateObject->TemplateAdd(
        Name  => 'Name',
        Items => [
            {
                Title         => '...',
                Comment       => '...',
                DueDateDiff   => '...',
                DateStartDiff => '...',
                Responsible   => '...',
                Status        => '...',
                Priority      => '...',
            },
        ],
        GroupIDs => [ 1, 2, 3 ],
        ValidID  => 123,
        UserID   => 123,
    );

=cut

sub TemplateAdd {
    my ( $Self, %Param ) = @_;

    my $JSONObject = $Kernel::OM->Get('Kernel::System::JSON');
    my $LogObject  = $Kernel::OM->Get('Kernel::System::Log');
    my $DBObject   = $Kernel::OM->Get('Kernel::System::DB');

    # check needed stuff
    for my $Needed ( qw(Name Items ValidID UserID) ) {
        if ( !$Param{$Needed} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
            return;
        }
    }

    if ( !ref $Param{Items} || ref $Param{Items} ne 'ARRAY' ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'Items has to be an array reference',
        );

        return;
    }

    # check if template exists
    my $NameExists = $Self->TemplateNameExists(
        Name => $Param{Name},
    );

    if ( $NameExists ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'Templatename already exists',
        );

        return;
    }

    my $Template    = $JSONObject->Encode( Data => $Param{Items} );
    my $Conditions  = $JSONObject->Encode( Data => $Param{Conditions}  || [] );
    my $CustomerIDs = $JSONObject->Encode( Data => $Param{CustomerIDs} || [] );

    # insert new item
    return if !$DBObject->Do(
        SQL => 'INSERT INTO ps_checklist_template '
            . '(tmpl_name, cl_template, valid_id, customer_ids,'
            . ' create_time, create_by, change_time, change_by, condition_actions) '
            . 'VALUES (?, ?, ?, ?, current_timestamp, ?, current_timestamp, ?, ?)',
        Bind => [
            \$Param{Name},
            \$Template,
            \$Param{ValidID},
            \$CustomerIDs,
            \$Param{UserID},
            \$Param{UserID},
            \$Conditions,
        ],
    );

    my $IDSelect = 'SELECT id FROM ps_checklist_template WHERE tmpl_name = ?';
    return if !$DBObject->Prepare(
        SQL   => $IDSelect,
        Bind  => [ \$Param{Name} ],
        Limit => 1,
    );

    my $ID;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $ID = $Row[0];
    }

    my $GroupInsert = 'INSERT INTO ps_checklist_tmpl_grp (template_id, group_id) '
        . ' VALUES (?,?)';

    for my $Group ( @{ $Param{GroupIDs} || [] } ) {
        $DBObject->Do(
            SQL  => $GroupInsert,
            Bind => [ \$ID, \$Group ],
        );
    }

    # log notice
    $LogObject->Log(
        Priority => 'notice',
        Message  => "TicketChecklistTemplate '$Param{Name}' created successfully ($Param{UserID})!",
    );

    return 1;
}


=item TemplateUpdate()

to update news 

    my $Success = $TemplateObject->TemplateUpdate(
        ID    => 3,
        Name  => 'Name',
        Items => [
            {
                Title       => '...',
                Comment     => '...',
                DueDateDiff => '...',
                Responsible => '...',
                Status      => '...',
                Priority    => '...',
            },
        ],
        ValidID => 123,
        UserID  => 123,
    );

=cut

sub TemplateUpdate {
    my ( $Self, %Param ) = @_;

    my $JSONObject = $Kernel::OM->Get('Kernel::System::JSON');
    my $LogObject  = $Kernel::OM->Get('Kernel::System::Log');
    my $DBObject   = $Kernel::OM->Get('Kernel::System::DB');

    # check needed stuff
    for my $Needed (qw(ID Name Items ValidID UserID)) {
        if ( !$Param{$Needed} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
            return;
        }
    }

    if ( !ref $Param{Items} || ref $Param{Items} ne 'ARRAY' ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'Items has to be an array reference',
        );

        return;
    }

    my $Template    = $JSONObject->Encode( Data => $Param{Items} );
    my $Conditions  = $JSONObject->Encode( Data => $Param{Conditions}  || [] );
    my $CustomerIDs = $JSONObject->Encode( Data => $Param{CustomerIDs} || [] );

    # insert new news
    return if !$DBObject->Do(
        SQL => 'UPDATE ps_checklist_template SET '
            . ' tmpl_name = ?, cl_template = ?, valid_id = ?,'
            . ' change_time = current_timestamp, change_by = ?, '
            . ' condition_actions = ?, customer_ids = ? '
            . ' WHERE id = ?',
        Bind => [
            \$Param{Name},
            \$Template,
            \$Param{ValidID},
            \$Param{UserID},
            \$Conditions,
            \$CustomerIDs,
            \$Param{ID},
        ],
    );

    return if !$DBObject->Do(
        SQL  => 'DELETE FROM ps_checklist_tmpl_grp WHERE template_id = ?',
        Bind => [ \$Param{ID} ],
    );

    my $GroupInsert = 'INSERT INTO ps_checklist_tmpl_grp (template_id, group_id) '
        . ' VALUES (?,?)';

    for my $Group ( @{ $Param{GroupIDs} || [] } ) {
        $DBObject->Do(
            SQL  => $GroupInsert,
            Bind => [ \$Param{ID}, \$Group ],
        );
    }

    return 1;
}

=item TemplateGet()

returns a hash with template data

    my %TemplateData = $TemplateObject->TemplateGet(
        ID => 2,
    );

This returns something like:

    %TemplateData = (
        ID         => 3,
        Name       => '...',
        Items      => [
        ],
        Groups     => [
        ],
        ValidID    => 1,
        CreateBy   => 354,
        CreateTime => '',
        ChangeBy   => 35,
        ChangeTime => '',
    );

=cut

sub TemplateGet {
    my ( $Self, %Param ) = @_;

    my $JSONObject  = $Kernel::OM->Get('Kernel::System::JSON');
    my $LogObject   = $Kernel::OM->Get('Kernel::System::Log');
    my $DBObject    = $Kernel::OM->Get('Kernel::System::DB');
    my $ValidObject = $Kernel::OM->Get('Kernel::System::Valid');

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
        SQL => 'SELECT id, tmpl_name, cl_template, valid_id, '
            . 'create_by, create_time, change_by, change_time, '
            . 'condition_actions, customer_ids '
            . 'FROM ps_checklist_template WHERE id = ?',
        Bind  => [ \$Param{ID} ],
        Limit => 1,
    );

    my %Template;
    while ( my @Data = $DBObject->FetchrowArray() ) {
        %Template = (
            ID         => $Data[0],
            Name       => $Data[1],
            Template   => $Data[2],
            ValidID    => $Data[3],
            CreateBy   => $Data[4],
            CreateTime => $Data[5],
            ChangeBy   => $Data[6],
            ChangeTime => $Data[7],
            Condition  => $Data[8],
            Customers  => $Data[9],
        );
    }

    return if !%Template;

    $Template{Valid} = $ValidObject->ValidLookup( ValidID => $Template{ValidID} );

    $Template{Items} = $JSONObject->Decode(
        Data => $Template{Template},
    );

    $Template{Conditions} = $JSONObject->Decode(
        Data => $Template{Condition} || '[]',
    );

    $Template{CustomerIDs} = $JSONObject->Decode(
        Data => $Template{Customers} || '[]',
    );

    return if !$DBObject->Prepare(
        SQL  => 'SELECT group_id FROM ps_checklist_tmpl_grp WHERE template_id = ?',
        Bind => [ \$Param{ID} ],
    );

    while ( my @Row = $DBObject->FetchrowArray() ) {
        push @{ $Template{GroupIDs} }, $Row[0];
    }

    return %Template;
}

=item TemplateDelete()

deletes a news entry. Returns 1 if it was successful, undef otherwise.

    my $Success = $TemplateObject->TemplateDelete(
        ID => 123,
    );

=cut

sub TemplateDelete {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');
    my $DBObject  = $Kernel::OM->Get('Kernel::System::DB');

    # check needed stuff
    if ( !$Param{ID} ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'Need ID',
        );
        return;
    }

    my $GrpSQL  = 'DELETE FROM ps_checklist_tmpl_grp WHERE template_id = ?';
    my $GrpBind = \$Param{ID};

    return if !$DBObject->Do(
        SQL  => $GrpSQL,
        Bind => [ $GrpBind ],
    );

    my $SQL  = 'DELETE FROM ps_checklist_template WHERE id = ?';
    my $Bind = \$Param{ID};

    return $DBObject->Do(
        SQL  => $SQL,
        Bind => [ $Bind ],
    );
}

sub TemplateList {
    my ($Self, %Param) = @_;

    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    my @Where;
    my @Bind;

    if ( $Param{GroupIDs} ) {
        @Bind  = map{ \$_ }(-1, @{ $Param{GroupIDs} || [] }); 
        my $In = join ', ', ('?') x @Bind;
        push @Where, " COALESCE(tg.group_id, -1) IN($In)";
    }

    if ( $Param{CustomerIDs} ) {
        my $CustomerWhere = " ( customer_ids IS NULL  OR customer_ids = '[]' ";

        CUSTOMERID:
        for my $CustomerID ( @{ $Param{CustomerIDs} } ) {
            next CUSTOMERID if !$CustomerID;

            $CustomerWhere .= ' OR ' .
                join ' OR ', map{ sprintf qq~customer_ids like '%%"$_"%%'~, $CustomerID }('%s');
        }

        push @Where, $CustomerWhere . ')';
    }

    if ( $Param{Valid} ) {
        push @Where, ' valid_id = 1 ';
    }

    my $Where = join ' AND ', @Where;
    $Where    = ' WHERE ' . $Where if $Where;

    return if !$DBObject->Prepare(
        SQL  => 'SELECT t.id, t.tmpl_name, COALESCE(tg.group_id, -1) AS gid FROM ps_checklist_template t '
            . '     LEFT OUTER JOIN ps_checklist_tmpl_grp tg ON t.id = tg.template_id '
            . ( $Where || '' ),
        Bind => \@Bind,
    );

    my %List;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $List{ $Row[0] } = $Row[1];
    }

    return %List;
}

sub TemplateNameExists {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');
    my $DBObject  = $Kernel::OM->Get('Kernel::System::DB');

    # check needed stuff
    if ( !$Param{Name} ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'Need Name',
        );

        return;
    }

    my $SQL  = 'SELECT id FROM ps_checklist_template WHERE tmpl_name = ?';
    my $Bind = \$Param{Name};

    return if !$DBObject->Prepare(
        SQL   => $SQL,
        Bind  => [ $Bind ],
        Limit => 1,
    );

    my $NameExists;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $NameExists = $Row[0];
    }

    return $NameExists;
}

1;

=back

=head1 TERMS AND CONDITIONS

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (AGPL). If you
did not receive this file, see L<http://www.gnu.org/licenses/agpl.txt>.

=cut

