# --
# Copyright (C) 2015 - 2022 Perl-Services.de, https://www.perl-services.de
# Copyright (C) 2026 Freicon GmbH & Co. KG, https://freicon.de/
# --
# Modified by Freicon GmbH & Co. KG, 2026-10-26: ported to OTOBO 11.
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package var::packagesetup::TicketChecklist;

use strict;
use warnings;

use utf8;

use List::Util qw(first);

our @ObjectDependencies = qw(
    Kernel::Config
    Kernel::System::SysConfig
    Kernel::System::SysConfig::DB
    Kernel::System::DB
    Kernel::System::Stats
);

=head1 NAME

TimeChecklist.pm - code to excecute during package installation

=head1 SYNOPSIS

All functions

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

    $Self->{FilePrefix} = 'TicketChecklist';

    return $Self;
}

=item CodeInstall()

run the code install part

    my $Result = $CodeObject->CodeInstall();

=cut

sub CodeInstall {
    my ( $Self, %Param ) = @_;

    # create dynamic fields 
    $Self->_DoSysConfigChanges();
    $Self->_CreateDynamicFields();

    # install stats
    $Kernel::OM->Get('Kernel::System::Stats')->StatsInstall(
        FilePrefix => $Self->{FilePrefix},
        UserID     => 1,
    );

    return 1;
}

=item CodeReinstall()

run the code reinstall part

    my $Result = $CodeObject->CodeReinstall();

=cut

sub CodeReinstall {
    my ( $Self, %Param ) = @_;

    # install stats
    $Kernel::OM->Get('Kernel::System::Stats')->StatsInstall(
        FilePrefix => $Self->{FilePrefix},
        UserID     => 1,
    );

    return 1;
}

=item CodeUpgrade()

run the code upgrade part

    my $Result = $CodeObject->CodeUpgrade();

=cut

sub CodeUpgrade {
    my ( $Self, %Param ) = @_;

    $Self->_RemoveObsoleteSettings();
    $Self->_DoSysConfigChanges();
    $Self->_CreateDynamicFields();

    # install stats
    $Kernel::OM->Get('Kernel::System::Stats')->StatsInstall(
        FilePrefix => $Self->{FilePrefix},
        UserID     => 1,
    );

    return 1;
}

=item CodeUninstall()

run the code uninstall part

    my $Result = $CodeObject->CodeUninstall();

=cut

sub CodeUninstall {
    my ( $Self, %Param ) = @_;

    # install stats
    $Kernel::OM->Get('Kernel::System::Stats')->StatsUninstall(
        FilePrefix => $Self->{FilePrefix},
        UserID     => 1,
    );

    return 1;
}

=item CodeUpgrade_5_0_1()

moves notifications from old notifications table to own table

=cut

sub CodeUpgrade_5_0_1 {
    my ($Self) = @_;

    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    my $CheckSelect = qq~
        SELECT id, notification_type, language
        FROM ps_checklist_notify
    ~;

    return if !$DBObject->Prepare(
        SQL => $CheckSelect,
    );

    my %ExistingNotifications;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        my $Key = sprintf "%s::%s", $Row[1], $Row[2];

        $ExistingNotifications{$Key} = $Row[0];
    }

    my $SelectCmd = qq~
        SELECT
            notification_type, notification_language, subject, text, 
            content_type, create_time, create_by, change_time, change_by
        FROM notifications
        WHERE notification_type LIKE 'Agent::TicketChecklist::%'
    ~;

    my $InsertCmd = qq~
        INSERT INTO ps_checklist_notify
            (notification_type, language, subject, notification_text,
            content_type, create_time, create_by, change_time, change_by)
        VALUES ( ?, ?, ?, ?, ?, ?, ?, ?, ? )
    ~;

    my $UpdateCmd = qq~
        UPDATE ps_checklist_notify
        SET
            notification_type = ?, language = ?, subject = ?, notification_text = ?,
            content_type = ?, create_time = ?, create_by = ?, change_time = ?, change_by = ?
        WHERE id = ?
    ~;

    return if !$DBObject->Prepare(
        SQL => $SelectCmd,
    );

    my @Notifications;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        push @Notifications, +{
            Type        => $Row[0],
            Language    => $Row[1],
            Subject     => $Row[2],
            Text        => $Row[3],
            ContentType => $Row[4],
            CreateTime  => $Row[5],
            CreateBy    => $Row[6],
            ChangeTime  => $Row[7],
            ChangeBy    => $Row[8],
        };
    }

    my @ToDelete = map{ \$_->{Type} } @Notifications;

    for my $Notification ( @Notifications ) {
        $Notification->{Type} =~ s{Agent::TicketChecklist::}{}xms;

        my @Bind;
        my $SQL = $InsertCmd;

        my $Key = sprintf "%s::%s", $Notification->{Type}, $Notification->{Language};
        if ( $ExistingNotifications{$Key} ) {
            $SQL  = $UpdateCmd;
            @Bind = ( \$ExistingNotifications{$Key} );
        }

        $DBObject->Do(
            SQL  => $SQL,
            Bind => [
                \$Notification->{Type},
                \$Notification->{Language},
                \$Notification->{Subject},
                \$Notification->{Text},
                \$Notification->{ContentType},
                \$Notification->{CreateTime},
                \$Notification->{CreateBy},
                \$Notification->{ChangeTime},
                \$Notification->{ChangeBy},
                @Bind,
            ],
        );
    }

    my $Placeholder = join ', ', ('?') x @ToDelete;
    my $DeleteSQL   = qq~
        DELETE FROM notifications WHERE notification_type IN( $Placeholder )
    ~;

    return if !$DBObject->Prepare(
        SQL  => $DeleteSQL,
        Bind => \@ToDelete,
    );

    return 1;
}

=item CodeUpgrade_5_0_24()

Set valid_id to 1 for existing notifications

=cut

sub CodeUpgrade_5_0_24 {
    my ($Self, %Param) = @_;

    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    return $DBObject->Do(
        SQL => 'UPDATE ps_checklist_notify SET valid_id = 1',
    );
}

=item _DoSysConfigChanges()

=cut

# Settings that earlier versions defined and this one no longer does. OTOBO only
# drops them on a package upgrade when the XML files of every installed package
# are deployed correctly (Kernel::System::Package::_ConfigurationDeploy), so on
# many systems they would survive. Ticket::CustomModule###10001-TicketChecklist
# would then keep requiring a module that is gone, and log an error for every
# ticket object. Same steps as Kernel::System::SysConfig::_DBCleanUp.
sub _RemoveObsoleteSettings {
    my ( $Self, %Param ) = @_;

    my $SysConfigDBObject = $Kernel::OM->Get('Kernel::System::SysConfig::DB');

    my $Removed;
    SETTING:
    for my $Name (qw(Ticket::CustomModule###10001-TicketChecklist)) {
        my %Setting = $SysConfigDBObject->DefaultSettingLookup( Name => $Name );
        next SETTING if !%Setting;

        for my $Modified ( $SysConfigDBObject->ModifiedSettingListGet( Name => $Name ) ) {
            $SysConfigDBObject->ModifiedSettingDelete( ModifiedID => $Modified->{ModifiedID} );
        }
        for my $Version ( $SysConfigDBObject->ModifiedSettingVersionListGet( Name => $Name ) ) {
            $SysConfigDBObject->ModifiedSettingVersionDelete( ModifiedVersionID => $Version->{ModifiedVersionID} );
        }

        $Removed++ if $SysConfigDBObject->DefaultSettingDelete( Name => $Name );
    }

    return 1 if !$Removed;

    # rewrite ZZZAAuto.pm, the package deployment has already run at this point
    return $Kernel::OM->Get('Kernel::System::SysConfig')->ConfigurationDeploy(
        Comments => 'TicketChecklist: obsolete settings removed',
        NotDirty => 1,
        UserID   => 1,
        Force    => 1,
    );
}

sub _DoSysConfigChanges {
    my ($Self, %Param) = @_;

    my $SysConfigObject = $Kernel::OM->Get('Kernel::System::SysConfig');
    my $ConfigObject    = $Kernel::OM->Get('Kernel::Config');

    my $Headers = $ConfigObject->Get('PostmasterX-Header') || [];
    my $Changed;

    my @NewHeaders = qw(
        X-OTRS-TicketChecklistID
        X-OTRS-FollowUp-TicketChecklistID
        X-OTRS-TicketChecklistName
        X-OTRS-FollowUp-TicketChecklistName
    );

    for my $NewHeader ( @NewHeaders ) {
        if ( !first{ $_ eq $NewHeader } @{ $Headers } ) {
            push @{$Headers}, $NewHeader;
            $Changed = 1;
        }
    }

    my @Suffixes = (
        "", map{"-" . $_}qw(Status StatusID DueDate ResponsibleID PriorityID)
    );

    for my $Index ( 1 .. 20 ) {
        my @Names = map{ sprintf "X-OTRS-TicketChecklistItem-%s%s", $Index, $_ }@Suffixes;

        for my $Name ( @Names ) {
            if ( !first{ $_ eq $Name } @{ $Headers } ) {
                push @{$Headers}, $Name;
                $Changed = 1;
            }
        }
    }

    my @Settings;
    if ( $Changed ) {
        push @Settings, {
            Name           => 'PostmasterX-Header',
            EffectiveValue => $Headers,
        };

        # update the sysconfig
        my $Success = $SysConfigObject->SettingsSet(
            UserID   => 1,
            Comments => 'Deactivate some dynamic fields added in earlier versions of ShowCustomerCIInfo',
            Settings => \@Settings,
        );
    }
}

=item _CreateDynamicFields()

creates all dynamic fields that are necessary for reporting 

    my $Result = $CodeObject->_CreateDynamicFields();

=cut

sub _CreateDynamicFields {
    my ( $Self, %Param ) = @_;

    my $ValidObject        = $Kernel::OM->Get('Kernel::System::Valid');
    my $DynamicFieldObject = $Kernel::OM->Get('Kernel::System::DynamicField');

    my $ValidID = $ValidObject->ValidLookup(
        Valid => 'valid',
    );

    # get all current dynamic fields
    my $DynamicFieldList = $DynamicFieldObject->DynamicFieldListGet(
        Valid => 0,
    );

    # get the list of order numbers (is already sorted).
    my @DynamicfieldOrderList;
    for my $Dynamicfield ( @{$DynamicFieldList} ) {
        push @DynamicfieldOrderList, $Dynamicfield->{FieldOrder};
    }

    # get the last element from the order list and add 1
    my $NextOrderNumber = 1;
    if (@DynamicfieldOrderList) {
        $NextOrderNumber = $DynamicfieldOrderList[-1] + 1;
    }

    # get the definition for all dynamic fields for ITSM
    my @DynamicFields = $Self->_GetDynamicFieldsDefinition();

    # create a dynamic fields lookup table
    my %DynamicFieldLookup;
    for my $DynamicField ( @{$DynamicFieldList} ) {
        next if ref $DynamicField ne 'HASH';
        $DynamicFieldLookup{ $DynamicField->{Name} } = $DynamicField;
    }

    # create or update dynamic fields
    DYNAMICFIELD:
    for my $DynamicField (@DynamicFields) {

        my $CreateDynamicField;

        # check if the dynamic field already exists
        if ( ref $DynamicFieldLookup{ $DynamicField->{Name} } ne 'HASH' ) {
            $CreateDynamicField = 1;
        }

        # check if new field has to be created
        if ($CreateDynamicField) {

            # create a new field
            my $FieldID = $DynamicFieldObject->DynamicFieldAdd(
                Name       => $DynamicField->{Name},
                Label      => $DynamicField->{Label},
                FieldOrder => $NextOrderNumber,
                FieldType  => $DynamicField->{FieldType},
                ObjectType => $DynamicField->{ObjectType},
                Config     => $DynamicField->{Config},
                ValidID    => $ValidID,
                UserID     => 1,
            );
            next DYNAMICFIELD if !$FieldID;

            # increase the order number
            $NextOrderNumber++;
        }

    }

    return 1;
}

=item _GetDynamicFieldsDefinition()

returns the definition for reporting related dynamic fields

    my $Result = $CodeObject->_GetDynamicFieldsDefinition();

=cut

sub _GetDynamicFieldsDefinition {
    my ( $Self, %Param ) = @_;

    # define all dynamic fields for reporting
    my @DynamicFields = (
        {
            Name       => 'TicketHasOpenTodos',
            Label      => 'Ticket has open todos',
            FieldType  => 'Text',
            ObjectType => 'Ticket',
            Config     => {
                DefaultValue => 0,
                Link         => '',
            },
        },
        {
            Name       => 'TicketChecklistTemplates',
            Label      => 'Templates used for the checklist',
            FieldType  => 'Text',
            ObjectType => 'Ticket',
            Config     => {
                DefaultValue => 0,
                Link         => '',
            },
        },
        {
            Name       => 'TicketChecklistConditionActions',
            Label      => 'Conditions and actions for Ticket',
            FieldType  => 'TextArea',
            ObjectType => 'Ticket',
            Config     => {
                DefaultValue => 0,
                Link         => '',
            },
        },
        {
            Name       => 'TicketHasChecklist',
            Label      => 'Ticket has a checklist',
            FieldType  => 'Text',
            ObjectType => 'Ticket',
            Config     => {
                DefaultValue => 0,
                Link         => '',
            },
        },
    );

    return @DynamicFields;
}

1;

=back

=head1 TERMS AND CONDITIONS

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (GPL). If you
did not receive this file, see L<http://www.gnu.org/licenses/gpl-2.0.txt>.

=cut

