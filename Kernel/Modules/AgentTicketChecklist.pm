# --
# Copyright (C) 2014 - 2022 Perl-Services.de, https://www.perl-services.de
# Copyright (C) 2026 Freicon GmbH & Co. KG, https://freicon.de/
# --
# Modified by Freicon GmbH & Co. KG, 2026-10-26: ported to OTOBO 11.
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AgentTicketChecklist;

use strict;
use warnings;

our @ObjectDependencies = qw(
    Kernel::Config
    Kernel::Output::HTML::Layout
    Kernel::System::Ticket
    Kernel::System::JSON
    Kernel::System::Priority
    Kernel::System::User
    Kernel::System::Group
    Kernel::System::DateTime
    Kernel::System::Web::Request
    Kernel::System::LinkObject
    Kernel::System::DynamicField
    Kernel::System::DynamicField::Backend
    Kernel::System::PerlServices::TicketChecklist
    Kernel::System::PerlServices::TicketChecklistUtils
    Kernel::System::PerlServices::TicketChecklistStatus
    Kernel::System::PerlServices::TicketChecklistTemplate
    Kernel::System::Cache
);

use Kernel::Language qw(Translatable);
use Kernel::System::VariableCheck qw(:all);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    $Self->{Config}->{Permission} = 'ro';

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $LayoutObject       = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $TicketObject       = $Kernel::OM->Get('Kernel::System::Ticket');
    my $ArticleObject      = $Kernel::OM->Get('Kernel::System::Ticket::Article');
    my $ParamObject        = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $ConfigObject       = $Kernel::OM->Get('Kernel::Config');
    my $ChecklistObject    = $Kernel::OM->Get('Kernel::System::PerlServices::TicketChecklist');
    my $UtilsObject        = $Kernel::OM->Get('Kernel::System::PerlServices::TicketChecklistUtils');
    my $StatusObject       = $Kernel::OM->Get('Kernel::System::PerlServices::TicketChecklistStatus');
    my $PriorityObject     = $Kernel::OM->Get('Kernel::System::Priority');
    my $JSONObject         = $Kernel::OM->Get('Kernel::System::JSON');
    my $UserObject         = $Kernel::OM->Get('Kernel::System::User');
    my $TemplateObject     = $Kernel::OM->Get('Kernel::System::PerlServices::TicketChecklistTemplate');
    my $CacheObject        = $Kernel::OM->Get('Kernel::System::Cache');
    my $DynamicFieldObject = $Kernel::OM->Get('Kernel::System::DynamicField');
    my $BackendObject      = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');
    my $LinkObject         = $Kernel::OM->Get('Kernel::System::LinkObject');
    my $GroupObject        = $Kernel::OM->Get('Kernel::System::Group');

    my $Output;

    my $TicketFormID = $ParamObject->GetParam( Param => 'TicketFormID' );

    my %Roles = $GroupObject->PermissionUserRoleGet(
        UserID => $Self->{UserID},
    );

    if ( $Self->{Subaction} && $Self->{Subaction} !~ m{\A New}xms && !$TicketFormID ) {

        # check needed stuff
        if ( !$Self->{TicketID} ) {
    
            # error page
            return $LayoutObject->ErrorScreen(
                Message => Translatable('No TicketID is given!'),
                Comment => Translatable('Please contact the admin.'),
            );
        }

        # check permissions
        if (
            !$TicketObject->TicketPermission(
                Type     => $Self->{Config}->{Permission},
                TicketID => $Self->{TicketID},
                UserID   => $Self->{UserID}
            )
            )
        {
    
            # error screen, don't show ticket
            return $LayoutObject->NoPermission(
                Message    => $LayoutObject->{LanguageObject}->Translate( 'You need %s permissions!', $Self->{Config}->{Permission} ),
                WithHeader => 'yes',
            );
        }
    
        # get ACL restrictions
        $TicketObject->TicketAcl(
            Data          => '-',
            TicketID      => $Self->{TicketID},
            ReturnType    => 'Action',
            ReturnSubType => '-',
            UserID        => $Self->{UserID},
        );
        my %AclAction = $TicketObject->TicketAclActionData();
    
        # check if ACL restrictions exist
        if ( IsHashRefWithData( \%AclAction ) ) {
    
            # show error screen if ACL prohibits this action
            if ( defined $AclAction{ $Self->{Action} } && $AclAction{ $Self->{Action} } eq '0' ) {
                return $LayoutObject->NoPermission( WithHeader => 'yes' );
            }
        }
    }
    elsif ( !$Self->{Subaction} ) {

        # check permissions
        if (
            !$TicketObject->TicketPermission(
                Type     => 'ro',
                TicketID => $Self->{TicketID},
                UserID   => $Self->{UserID}
            )
            )
        {
    
            # error screen, don't show ticket
            return $LayoutObject->NoPermission(
                Message    => $LayoutObject->{LanguageObject}->Translate( 'You need %s permissions!', 'ro' ),
                WithHeader => 'yes',
            );
        }
    }

    my $OnlyROPermissions = 0;
    my $RWGroups          = $ConfigObject->Get('TicketChecklist::RWGroups') || [];

    if ( @{ $RWGroups || [] } ) {

        # Get all groups the user has rw-permissions
        my %UserGroups = $GroupObject->PermissionUserGet(
            UserID => $Self->{UserID},
            Type   => 'rw',
        );

        # get a list of all groups as we get the ids in the request above and
        # have names in the sysconfig option
        my %GroupList        = $GroupObject->GroupList( Valid => 1 );
        my %GroupListReverse = reverse %GroupList;

        my @UserGroupsNames = map{
            my $GroupID = $GroupListReverse{$_};
            ($UserGroups{$GroupID} && $GroupList{$GroupID} ) ? $_ : ();
        } @{ $RWGroups || [] };

        # if
        $OnlyROPermissions++ if !@UserGroupsNames;
    }

    if ( $OnlyROPermissions  && $Self->{Subaction} ) {
        return $LayoutObject->ErrorScreen(
            Message => Translatable('No permission to save the checklist!'),
            Comment => Translatable('Please contact the admin.'),
        );
    }

    if ( $Self->{Subaction} eq 'ReloadWidget' ) {
        my $OutputFilter = $Kernel::OM->Get('Kernel::Output::HTML::FilterContent::TicketChecklist');
        my $HTML         = $OutputFilter->Run( ReturnHTML => 1 );
        my $JSON         = $JSONObject->Encode( Data => {
            Success => 1,
            HasHTML => 1,
            HTML    => $HTML,
        });

        return $LayoutObject->Attachment(
            ContentType => 'application/json; charset=' . $LayoutObject->{Charset},
            Content     => $JSON,
            Type        => 'inline',
            NoCache     => 1,
        );
    }

    if ( $Self->{Subaction} eq 'Save' ) {

        # challenge token check for write action
        $LayoutObject->ChallengeTokenCheck();

        my %Error;

        my @ChecklistItems;

        my $DefaultPriority   =
            $Self->TicketPriority( TicketID => $Self->{TicketID} ) || 
            $ConfigObject->Get('TicketChecklist::DefaultPriority') ||
            '3 normal';
        my $DefaultPriorityID = $PriorityObject->PriorityLookup( Priority => $DefaultPriority );

        my @ArticleBox;
        if ( $Self->{TicketID} ) {
            @ArticleBox = $ArticleObject->ArticleList(
                TicketID => $Self->{TicketID},
                UserID   => $Self->{UserID},
            );
        }

        my %TicketArticleBoxes;

        my $PastDueDatesAllowed = $ConfigObject->Get('TicketChecklist::PastDueDatesAllowed');

        my $PosCounter = 1;
        my $ItemOrder  = $ParamObject->GetParam( Param => 'ItemOrder' ) || '';
        for my $Pos ( split /,/, $ItemOrder ) {
            my $Title          = $ParamObject->GetParam( Param => 'ItemTitle_' . $Pos );
            my $State          = $ParamObject->GetParam( Param => 'ItemStatus_' . $Pos );
            my $ID             = $ParamObject->GetParam( Param => 'ItemID_' . $Pos );
            my $PriorityID     = $ParamObject->GetParam( Param => 'ItemPriorityID_' . $Pos );
            my $ResponsibleID  = $ParamObject->GetParam( Param => 'ItemResponsibleID_' . $Pos );
            my $Comment        = $ParamObject->GetParam( Param => 'ItemComment_' . $Pos );
            my $ChangeNote     = $ParamObject->GetParam( Param => 'ItemChangeNote_' . $Pos );
            my $ArticleNumber  = $ParamObject->GetParam( Param => 'ItemArticleNumber_' . $Pos );
            my $Responsible    = $ParamObject->GetParam( Param => 'Responsible_' . $Pos );

            my %Item;
            if ( $ID ) {
                %Item = $ChecklistObject->TicketChecklistGet( ID => $ID );
            }

            my $ArticleID;
            if ( $ArticleNumber ) {
                my $LocalArticleNumber = $ArticleNumber;
                my $TicketNumber;
                if ( $ArticleNumber =~ m{\#}xms ) {
                    ($TicketNumber, $LocalArticleNumber) = split /\#/, $ArticleNumber;
                }

                my @LocalArticleBox = @ArticleBox;
                if ( $TicketNumber ) {
                    my $TicketID = $TicketObject->TicketIDLookup(
                        TicketNumber => $TicketNumber,
                        UserID       => $Self->{UserID},
                    );

                    if ( $TicketID ) {
                        if ( !$TicketArticleBoxes{$TicketID} ) {
                            my @ArticleBox = $ArticleObject->ArticleList(
                                TicketID => $TicketID,
                                UserID   => $Self->{UserID},
                            );
    
                            $TicketArticleBoxes{$TicketID} = \@ArticleBox;
                        }
    
                        @LocalArticleBox = @{ $TicketArticleBoxes{$TicketID} || [] };
                    }
                }

                my $Index   = $LocalArticleNumber - 1;
                my $Article = $LocalArticleBox[$Index] || {};

                $ArticleID = $Article->{ArticleID};
            }

            my $DueDate;
            my $Fieldname = 'ItemDueDate_' . $Pos . '_';
            if ( $ParamObject->GetParam( Param => $Fieldname . 'Used' ) ) {
                my %GetParam;
                for my $Type (qw(Year Month Day Hour Minute)) {
                    $GetParam{ $Fieldname . $Type } =
                        $ParamObject->GetParam( Param => $Fieldname . $Type );
                }

                if (
                    $GetParam{$Fieldname . 'Year'}
                    && $GetParam{$Fieldname . 'Month'}
                    && $GetParam{$Fieldname . 'Day'}
                    && defined $GetParam{$Fieldname . 'Hour'}
                    && defined $GetParam{$Fieldname . 'Minute'}
                    )
                {
    
                    # transform change requested time, time stamp based on user time zone
                    %GetParam = $LayoutObject->TransformDateSelection(
                        %GetParam,
                        Prefix => $Fieldname,
                    );
    
                    # format as timestamp, when all required time params were passed
                    $DueDate = sprintf '%04d-%02d-%02d %02d:%02d:00',
                        $GetParam{$Fieldname . 'Year'},
                        $GetParam{$Fieldname . 'Month'},
                        $GetParam{$Fieldname . 'Day'},
                        $GetParam{$Fieldname . 'Hour'},
                        $GetParam{$Fieldname . 'Minute'};

                    # check if date was changed and if it was changed, check if the date
                    # is in the past. That should be forbidden.
                    if ( !$PastDueDatesAllowed && ( !%Item || ( %Item && $DueDate ne $Item{DueDate} ) ) ) {
                        my ($DueDateDay) = split / /, $DueDate;
                        my ($NowDay)     = split / /, $Kernel::OM->Create('Kernel::System::DateTime')->ToString();

                        my $IsInPast = $DueDateDay lt $NowDay;

                        $Error{ 'ItemDueDate_' . $PosCounter } = 'ServerError' if $IsInPast;
                    }
                }
            }

            my $DateStart;
            my $StartFieldname = 'ItemDateStart_' . $Pos . '_';
            if ( $ParamObject->GetParam( Param => $StartFieldname . 'Used' ) ) {
                my %GetParam;
                for my $Type (qw(Year Month Day Hour Minute)) {
                    $GetParam{ $StartFieldname . $Type } =
                        $ParamObject->GetParam( Param => $StartFieldname . $Type );
                }

                if (
                    $GetParam{$StartFieldname . 'Year'}
                    && $GetParam{$StartFieldname . 'Month'}
                    && $GetParam{$StartFieldname . 'Day'}
                    && defined $GetParam{$StartFieldname . 'Hour'}
                    && defined $GetParam{$StartFieldname . 'Minute'}
                    )
                {

                    # transform change requested time, time stamp based on user time zone
                    %GetParam = $LayoutObject->TransformDateSelection(
                        %GetParam,
                        Prefix => $StartFieldname,
                    );

                    # format as timestamp, when all required time params were passed
                    $DateStart = sprintf '%04d-%02d-%02d %02d:%02d:00',
                        $GetParam{$StartFieldname . 'Year'},
                        $GetParam{$StartFieldname . 'Month'},
                        $GetParam{$StartFieldname . 'Day'},
                        $GetParam{$StartFieldname . 'Hour'},
                        $GetParam{$StartFieldname . 'Minute'};
                }
            }

            # check if the start date is before the due date
            if ( $DateStart && $DueDate lt $DateStart ) {
                $Error{ 'ItemDateStart_' . $PosCounter } = 'ServerError';
            }

            # Import some ticket data
            my $ForeignTicketID;
            if ( $Title =~ m{\A[#]}xms && $ConfigObject->Get('TicketChecklist::AllowTicketsAsItems') ) {
                (my $Number = $Title) =~ s{\A[#]}{}xms;

                $ForeignTicketID = $TicketObject->TicketIDLookup(
                    TicketNumber => $Number,
                    UserID       => $Self->{UserID},
                );

                if ( $ForeignTicketID ) {
                    my %Ticket = $TicketObject->TicketGet(
                        TicketID => $ForeignTicketID,
                        UserID   => $Self->{UserID},
                    );

                    $Comment       = $Ticket{Title};
                    #$DueDate       = $Ticket{};
                    $PriorityID    = $Ticket{PriorityID};
                    $ResponsibleID = $Ticket{OwnerID};

                    my $Mapping  = $ConfigObject->Get('TicketChecklist::TicketStateToItemState') || {};
                    my $NewState = $Mapping->{ $Ticket{State} };
                    if ( $NewState ) {
                        my $NewStateID = $StatusObject->TicketChecklistStatusLookup( Name => $NewState );
                        $State         = $NewStateID if $NewStateID;
                    }

                    # link ticket
                    if ( $ConfigObject->Get('TicketChecklist::LinkTickets') ) {
                        $LinkObject->LinkAdd(
                            SourceObject => 'Ticket',
                            SourceKey    => $Self->{TicketID},
                            TargetObject => 'Ticket',
                            TargetKey    => $ForeignTicketID,
                            Type         => 'ParentChild',
                            State        => 'Valid',
                            UserID       => $Self->{UserID},
                        );
                    }
                }
            }

            push @ChecklistItems, +{
                StatusID        => $State,
                ID              => $ID,
                Title           => $Title,
                Position        => $PosCounter,
                PriorityID      => $PriorityID || $DefaultPriorityID,
                ResponsibleID   => $ResponsibleID || $Self->{UserID},
                ResponsibleKey  => $Responsible,
                DueDate         => $DueDate,
                DateStart       => $DateStart,
                Comment         => $Comment,
                ArticleNumber   => $ArticleNumber,
                ArticleID       => $ArticleID,
                ChangeNote      => $ChangeNote,
                ForeignTicketID => $ForeignTicketID || 0,
            };

            if ( !defined $Title ) {
                $Error{ 'ItemTitle_' . $PosCounter } = 'ServerError';
            }

            if ( !defined $State ) {
                $Error{ 'ItemStatus_' . $PosCounter } = 'ServerError';
            }

            $PosCounter++;
        }

        # check needed data
        if (%Error) {
            return $Self->Form(
                %Param,
                Errors => \%Error,
                Items => \@ChecklistItems,
            );
        }

        if ( $TicketFormID ) {
            $CacheObject->Set(
                Type  => 'TicketChecklist',
                Key   => $TicketFormID,
                Value => $JSONObject->Encode( Data => \@ChecklistItems ),
                TTL   => 24 * 60 * 60, # live one hour
            );

            my $Output = $LayoutObject->Header( Type => 'Small' );
            $Output .= $LayoutObject->Output(
                Template => q~[% WRAPPER JSOnDocumentComplete %]
<script type="text/javascript">//<![CDATA[
if (window.opener) {
    window.opener.ReloadChecklist();
    window.close();
}
//]]></script>
[% END %]~
            );

            $Output .= $LayoutObject->Footer( Type => 'Small' );

            return $Output;
        }

        my $IsFromTemplate = $ParamObject->GetParam( Param => 'ChecklistTemplateSelected' );
        if ( $IsFromTemplate ) {
            $ChecklistObject->TicketChecklistDelete(
                TicketID => $Self->{TicketID},
                UserID   => $Self->{UserID},
            );
        }

        my $TicketID = $Self->{TicketID};

        my @TicketItems = $ChecklistObject->TicketChecklistTicketGet(
            TicketID => $TicketID,
            UserID   => $Self->{UserID},
        );

        if ( !@TicketItems && @ChecklistItems ) {
            $ChecklistObject->TicketChecklistCreate(
                TicketID => $TicketID,
                UserID   => $Self->{UserID},
            );
        }

        my %ItemMap = map{ $_->{ID} => $_->{Title} }@TicketItems;

        my $Counter = 1;

        my $OverrideChangeNote = $ConfigObject->Get('TicketChecklist::EditChangeNote');

        POS:
        for my $Item ( @ChecklistItems ) {

            my %Opts = %{ $Item };
            my $ID   = delete $Opts{ID};

            my $Method = 'TicketChecklistAdd';
            if ( $ID ) {
                $Method   = 'TicketChecklistUpdate';
                $Opts{ID} = $ID;

                delete $ItemMap{$ID};
            }

            $ChecklistObject->$Method(
                %Opts,
                Override => $OverrideChangeNote,
                TicketID => $TicketID,
                Position => $Counter++,
                UserID   => $Self->{UserID},
            );
        }

        for my $ID ( keys %ItemMap ) {
            $ChecklistObject->TicketChecklistDelete(
                ID     => $ID,
                UserID => $Self->{UserID},
            );
        }

        my $FieldName = 'TicketChecklistTemplates';
        my $Field     = $DynamicFieldObject->DynamicFieldGet( Name => $FieldName );

        $BackendObject->ValueSet(
            DynamicFieldConfig => $Field,
            ObjectID           => $TicketID,
            Value              => $ParamObject->GetParam( Param => 'ChecklistTemplates') || '',
            UserID             => $Self->{UserID},
        );

        if ( !@ChecklistItems ) {
            $ChecklistObject->TicketChecklistRemove(
                TicketID => $TicketID,
                UserID   => $Self->{UserID},
            );

            $BackendObject->ValueSet(
                DynamicFieldConfig => $Field,
                ObjectID           => $TicketID,
                Value              => '',
                UserID             => $Self->{UserID},
            );
        }

        # redirect
        return $LayoutObject->PopupClose(
            URL => "Action=AgentTicketZoom;TicketID=$Self->{TicketID}",
        );
    }

    # new item
    elsif ( $Self->{Subaction} eq 'NewItem' ) {
        my %Ticket = $TicketObject->TicketGet(
            TicketID => $Self->{TicketID},
            UserID   => $Self->{UserID},
        );

        my $UsePosition  = $ParamObject->GetParam( Param => 'UsePosition' );
        my $Position     = $UsePosition ? $UsePosition - 1 : $ParamObject->GetParam( Param => 'Position' );
        my $DefaultValue = $ConfigObject->Get( 'TicketChecklist::DefaultState' ) || 'open';
        my %StatusList   = $StatusObject->TicketChecklistStatusList(
            Queues => [ $Ticket{QueueID} ],
            Roles  => [ keys %Roles ],
        );

        my %Agents     = $UserObject->UserList(
            Type  => 'Long',
            Valid => 1,
        );

        if ( !$ConfigObject->Get('TicketChecklist::AllUsersForResponsibles') ) {
            %Agents = $UtilsObject->TicketPossibleResponsibles(
                TicketID => $Self->{TicketID},
                Agents   => \%Agents,
            );
        }

        my $DefaultPriority =
            $Self->TicketPriority( TicketID => $Self->{TicketID} ) || 
            $ConfigObject->Get('TicketChecklist::DefaultPriority') ||
            '3 normal';

        my %Priorities = $PriorityObject->PriorityList(
            Valid => 1,
        );

        my $StatusDropDown = $LayoutObject->BuildSelectionJSON([
            {
                Name          => 'ItemStatus_' . ++$Position,
                Data          => \%StatusList,
                Translation   => 1,
                SelectedValue => $DefaultValue,
            },
            {
                Name         => 'ItemResponsibleID_' . $Position,
                Data         => \%Agents,
                PossibleNone => 1,
            },
            {
                Name          => 'ItemPriorityID_' . $Position,
                Data          => \%Priorities,
                SelectedValue => $DefaultPriority,
                Translation   => 1,
            },
        ]);

        my $Prefix = 'ItemDueDate_' . $Position . '_';
        my $DateDropDown = $LayoutObject->BuildDateSelection(
            Prefix               => $Prefix,
            Format               => 'DateInputFormatLong',
            YearPeriodPast       => 0,
            YearPeriodFuture     => 5,
            Class                => $Param{Errors}->{DateInvalid} || ' ',
            DiffTime             => 1,
            $Prefix . 'Optional' => 1,
        );
        my $DateJSON = $JSONObject->Encode(
            Data => { HTML => $DateDropDown },
        );

        my $StartPrefix = 'ItemDateStart_' . $Position . '_';
        my $StartDateDropDown = $LayoutObject->BuildDateSelection(
            Prefix                    => $StartPrefix,
            Format                    => 'DateInputFormatLong',
            YearPeriodPast            => 0,
            YearPeriodFuture          => 5,
            Class                     => $Param{Errors}->{DateInvalid} || ' ',
            DiffTime                  => 1,
            $StartPrefix . 'Optional' => 1,
        );

        my $StartDateJSON = $JSONObject->Encode(
            Data => { HTML => $StartDateDropDown },
        );

        my $JSON = sprintf '{ "Status":%s, "Position":%s, "DueDate": %s, "DateStart": %s }',
            $StatusDropDown, $Position, $DateJSON, $StartDateJSON;

        return $LayoutObject->Attachment(
            ContentType => 'application/json; charset=' . $LayoutObject->{Charset},
            Content     => $JSON,
            Type        => 'inline',
            NoCache     => 1,
        );
    }

    # load template
    elsif ( $Self->{Subaction} eq 'NewFromTemplate' ) {
        my %Ticket = $TicketObject->TicketGet(
            TicketID => $Self->{TicketID},
            UserID   => $Self->{UserID},
        );

        my $ID          = $ParamObject->GetParam( Param => 'TemplateID' );
        my $CurPosition = $ParamObject->GetParam( Param => 'Position' );

        my %Template = $TemplateObject->TemplateGet( ID => $ID );

        if ( !%Template || !@{ $Template{Items} || [] } ) {
            return $LayoutObject->Attachment(
                ContentType => 'application/json; charset=' . $LayoutObject->{Charset},
                Content     => sprintf( '{"Error":"Cannot find Template %s"}', $ID ),
                Type        => 'inline',
                NoCache     => 1,
            );
        }

        my %StatusList = $StatusObject->TicketChecklistStatusList(
            Queues => [ $Ticket{QueueID} ],
            Roles  => [ keys %Roles ],
        );
        my %Agents     = $UserObject->UserList(
            Type  => 'Long',
            Valid => 1,
        );
    
        my %Priorities = $PriorityObject->PriorityList(
            Valid => 1,
        );

        if ( !$ConfigObject->Get('TicketChecklist::AllUsersForResponsibles') ) {
            %Agents = $UtilsObject->TicketPossibleResponsibles(
                TicketID => $Self->{TicketID},
                Agents   => \%Agents,
            );
        }

        my $Position = 1;

        my $KeepEntries = $ConfigObject->Get('TicketChecklist::KeepEntriesOnTemplateChange');
        if ( $KeepEntries ) {
            $Position = $CurPosition + 1;
        }

        my $UseAutocomplete = $ConfigObject->Get('TicketChecklist::ResponsibleAutocomplete') ? 1 : 0;
        for my $Item ( @{ $Template{Items} } ) {
            $Item->{StatusSelect} = $LayoutObject->BuildSelection(
                Data        => \%StatusList,
                Name        => 'ItemStatus_' . $Position,
                SelectedID  => $Item->{Status},
                Size        => 1,
                Translation => 1,
                Class       => 'Modernize',
            );
    
            $Item->{PrioritySelect} = $LayoutObject->BuildSelection(
                Data        => \%Priorities,
                Name        => 'ItemPriorityID_' . $Position,
                SelectedID  => $Item->{Priority},
                Size        => 1,
                Translation => 1,
                Class       => 'Modernize',
            );
    
            $Item->{ResponsibleSelect} = $LayoutObject->BuildSelection(
                Data          => \%Agents,
                Name          => 'ItemResponsibleID_' . $Position,
                Size          => 1,
                PossibleNone  => 1,
                SelectedID    => $Item->{Responsible},
                Class         => 'Modernize',
            );

            if ( $UseAutocomplete ) {
                $Item->{ResponsibleSelect} = '';
            }

            my $YearsInPast = $ConfigObject->Get('TicketChecklist::DueDateYearsInPast') // 0;

            my $StartPrefix   = 'ItemDateStart_' . $Position . '_';
            my %StartDateOpts;

            if ( $Item->{DateStartDiff} ) {
                %StartDateOpts = ( $StartPrefix . 'Used' => 1 );
            }

            $Item->{DateStartSelect} = $LayoutObject->BuildDateSelection(
                %StartDateOpts,
                Prefix                    => $StartPrefix,
                Format                    => 'DateInputFormatLong',
                YearPeriodPast            => $YearsInPast,
                YearPeriodFuture          => 5,
                DiffTime                  => ( $Item->{DateStartDiff} || 1 ) * 60,
                Validate                  => 1,
                ValidateDateInFuture      => 1,
                $StartPrefix . 'Optional' => 1,
            );

            my $Prefix   = 'ItemDueDate_' . $Position . '_';
            my %DateOpts;

            if ( $Item->{DueDateDiff} ) {
                %DateOpts = ( $Prefix . 'Used' => 1 );
            }
    
            $Item->{DueDateSelect} = $LayoutObject->BuildDateSelection(
                %DateOpts,
                Prefix               => $Prefix,
                Format               => 'DateInputFormatLong',
                YearPeriodPast       => $YearsInPast,
                YearPeriodFuture     => 5,
                DiffTime             => ( $Item->{DueDateDiff} || 1 ) * 60,
                Validate             => 1,
                ValidateDateInFuture => 1,
                $Prefix . 'Optional' => 1,
            );

            $Item->{Position} = $Position;

            $LayoutObject->Block(
                Name => 'Item',
                Data => $Item,
            );

            if ( $UseAutocomplete ) {
                my $AutocompleteModule = $ConfigObject->Get('TicketChecklist::ResponsibleAutocompleteModule')
                    // 'Agent';
                my $AutocompleteObject = $Kernel::OM->Get(
                   'Kernel::System::PerlServices::TicketChecklist::Autocomplete::' . $AutocompleteModule
                );

                my $Fullname = $AutocompleteObject->Fullname(
                    UserLogin => $Item->{ResponsibleKey} || $Item->{ResponsibleID},
                );

                $LayoutObject->Block(
                    Name => 'ResponsibleAutocomplete',
                    Data => {
                        %{$Item},
                        TextValue => $Fullname,
                        Value => $Item->{ResponsibleKey} || $Item->{ResponsibleID},
                    },
                );
            }

            $Position++;
        }

        my $Theme = $ConfigObject->Get('TicketChecklist::Theme') || 'Standard';
        my $Slim  = $Theme eq 'Slim' ? 'Slim' : '';

        my $ItemList = $LayoutObject->Output(
            TemplateFile => 'ChecklistItemsSnippet' . $Slim,
            Data         => {},
        );

        my $JSON = $JSONObject->Encode(
            Data => {
                HTML        => $ItemList,
                Positions   => $Position-1,
                KeepEntries => $KeepEntries,
            },
        );

        return $LayoutObject->Attachment(
            ContentType => 'application/json; charset=' . $LayoutObject->{Charset},
            Content     => $JSON,
            Type        => 'inline',
            NoCache     => 1,
        );
    }

    # delete item
    elsif ( $Self->{Subaction} eq 'Delete' ) {
        my $ID = $ParamObject->GetParam( Param => 'ID' );

        if ( $ID ) {
            $ChecklistObject->TicketChecklistDelete(
                ID     => $ID,
                UserID => $Self->{UserID},
            );
        }

        return $LayoutObject->Attachment(
            ContentType => 'application/json; charset=' . $LayoutObject->{Charset},
            Content     => '{"Success":1}',
            Type        => 'inline',
            NoCache     => 1,
        );
    }

    elsif ( $Self->{Subaction} eq 'MoveItemToTicket' ) {
        my $ItemID   = $ParamObject->GetParam( Param => 'ItemID' );
        my $TicketNr = $ParamObject->GetParam( Param => 'TicketNumber' );

        my %ChecklistItem = $ChecklistObject->TicketChecklistGet(
            ID => $ItemID,
        );

        my $TicketID = $TicketObject->TicketIDLookup(
            TicketNumber => $TicketNr,
            UserID       => $Self->{UserID},
        );

        if ( !$TicketID || !%ChecklistItem ) {
            return $LayoutObject->Attachment(
                ContentType => 'application/json; charset=' . $LayoutObject->{Charset},
                Content     => '{"Success":0,"Message":"NoAccess"}',
                Type        => 'inline',
                NoCache     => 1,
            );
        }

        my @TicketChecklist = $ChecklistObject->TicketChecklistTicketGet(
            TicketID => $TicketID,
        );

        if ( !@TicketChecklist ) {
            $ChecklistObject->TicketChecklistCreate( TicketID => $TicketID );
        }

        my $Success = $ChecklistObject->TicketChecklistUpdate(
            %ChecklistItem,
            TicketID => $TicketID,
            UserID   => $Self->{UserID},
        );

        return $LayoutObject->Attachment(
            ContentType => 'application/json; charset=' . $LayoutObject->{Charset},
            Content     => '{"Success":1}',
            Type        => 'inline',
            NoCache     => 1,
        );
    }

    # show form
    else {
        my @ChecklistItems;

        my $TicketFormID = $ParamObject->GetParam( Param => 'TicketFormID' );
        if ( $TicketFormID ) {
            my $Checklist = $CacheObject->Get(
                Type  => 'TicketChecklist',
                Key   => $TicketFormID,
            );

            @ChecklistItems = @{ $JSONObject->Decode( Data => $Checklist ) || [] };
        }
        else {
            @ChecklistItems = $ChecklistObject->TicketChecklistTicketGet(
                TicketID => $Self->{TicketID},
            );

            my %Ticket = $TicketObject->TicketGet(
                TicketID      => $Self->{TicketID},
                DynamicFields => 1,
                UserID        => $Self->{UserID},
            );

            $Param{ChecklistTemplates} = $Ticket{DynamicField_TicketChecklistTemplates};
        }

        my $TicketPriority = $Self->TicketPriority( TicketID => $Self->{TicketID}, Return => 'ID' );

        return $Self->Form(
            %Param,
            TicketFormID   => $TicketFormID,
            Items          => \@ChecklistItems,
            TicketPriority => $TicketPriority,
            Readonly       => $OnlyROPermissions,
        );
    }
}

sub TicketPriority {
    my ( $Self, %Param ) = @_;

    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    my $Source = $ConfigObject->Get('TicketChecklist::PrioritySource') || 'DefaultPriority';

    return if $Source ne 'Ticket';
    return if !$Param{TicketID};

    my %Ticket = $TicketObject->TicketGet(
        TicketID => $Param{TicketID},
    );

    return if !%Ticket;

    return $Ticket{PriorityID} if $Param{Return} && $Param{Return} eq 'ID';
    return $Ticket{Priority};
}

sub Form {
    my ( $Self, %Param ) = @_;

    my $LayoutObject    = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $StatusObject    = $Kernel::OM->Get('Kernel::System::PerlServices::TicketChecklistStatus');
    my $UtilsObject     = $Kernel::OM->Get('Kernel::System::PerlServices::TicketChecklistUtils');
    my $TicketObject    = $Kernel::OM->Get('Kernel::System::Ticket');
    my $ParamObject     = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $PriorityObject  = $Kernel::OM->Get('Kernel::System::Priority');
    my $JSONObject      = $Kernel::OM->Get('Kernel::System::JSON');
    my $ConfigObject    = $Kernel::OM->Get('Kernel::Config');
    my $UserObject      = $Kernel::OM->Get('Kernel::System::User');
    my $TemplateObject  = $Kernel::OM->Get('Kernel::System::PerlServices::TicketChecklistTemplate');
    my $GroupObject     = $Kernel::OM->Get('Kernel::System::Group');

    my %Ticket = $TicketObject->TicketGet(
        TicketID => $Self->{TicketID},
        UserID   => $Self->{UserID},
    );

    my %Roles = $GroupObject->PermissionUserRoleGet(
        UserID => $Self->{UserID},
    );

    my %StatusList = $StatusObject->TicketChecklistStatusList(
        Queues => [ $Ticket{QueueID} ],
        Roles  => [ keys %Roles ],
    );

    my %Agents = $UserObject->UserList(
        Type  => 'Long',
        Valid => 1,
    );

    if ( !$ConfigObject->Get('TicketChecklist::AllUsersForResponsibles') ) {
        %Agents = $UtilsObject->TicketPossibleResponsibles(
            TicketID => $Self->{TicketID},
            Agents   => \%Agents,
        );
    }

    my %Priorities = $PriorityObject->PriorityList(
        Valid => 1,
    );

    my $ShowChangeNote       = $ConfigObject->Get('TicketChecklist::ShowChangeNotes') ? 1 : 0;
    my $EditChangeNote       = $ConfigObject->Get('TicketChecklist::EditChangeNote') ? 1 : 0;
    my $ShowChangeNoteWidget = $ConfigObject->Get('TicketChecklist::ShowChangeNotesWidget') ? 1 : 0;
    my $UseAutocomplete      = $ConfigObject->Get('TicketChecklist::ResponsibleAutocomplete') ? 1 : 0;
    my $AutocompleteModule   = $ConfigObject->Get('TicketChecklist::ResponsibleAutocompleteModule') // 'Agent';

    my $Counter = 1;
    for my $Item ( @{ $Param{Items} || [] } ) {
        $Item->{Position}     = $Counter++;
        $Item->{StatusSelect} = $LayoutObject->BuildSelection(
            Name        => 'ItemStatus_' . $Item->{Position},
            Data        => \%StatusList,
            SelectedID  => $Item->{StatusID} || $Item->{Status},
            Translation => 1,
            Class       => 'Modernize',
        );

        $Item->{ResponsibleSelect} = $LayoutObject->BuildSelection(
            Name         => 'ItemResponsibleID_' . $Item->{Position},
            Data         => \%Agents,
            SelectedID   => $Item->{ResponsibleID},
            PossibleNone => 1,
            Class        => 'Modernize',
        );

        if ( $UseAutocomplete ) {
            $Item->{ResponsibleSelect} = '';
        }

        $Item->{PrioritySelect} = $LayoutObject->BuildSelection(
            Name        => 'ItemPriorityID_' . $Item->{Position},
            Data        => \%Priorities,
            SelectedID  => $Item->{PriorityID},
            Translation => 1,
            Class       => 'Modernize',
        );

        my $YearsInPast = $ConfigObject->Get('TicketChecklist::DueDateYearsInPast') // 0;

        my $StartPrefix = 'ItemDateStart_' . $Item->{Position} . '_';
        my %StartDateOpts;
        if ( $Item->{DateStart} ) {
            %StartDateOpts = $Self->_DateSelectionValues(
                TimeStamp => $Item->{DateStart},
                Prefix    => $StartPrefix,
            );

            $StartDateOpts{ $StartPrefix . 'Used' } = 1;
        }

        my $DateStartError = $Param{Errors}->{"ItemDateStart_" . $Item->{Position}};
        $Item->{DateStartSelect} = $LayoutObject->BuildDateSelection(
            %StartDateOpts,
            Prefix                    => $StartPrefix,
            Format                    => 'DateInputFormatLong',
            YearPeriodPast            => $YearsInPast,
            YearPeriodFuture          => 5,
            $StartPrefix . 'Class'    => $DateStartError || ' ',
            DiffTime                  => 1,
            $StartPrefix . 'Optional' => 1,
        );

        my $Prefix = 'ItemDueDate_' . $Item->{Position} . '_';
        my %DateOpts;
        if ( $Item->{DueDate} ) {
            %DateOpts = $Self->_DateSelectionValues(
                TimeStamp => $Item->{DueDate},
                Prefix    => $Prefix,
            );

            $DateOpts{ $Prefix . 'Used' } = 1;
        }

        my $DueDateError = $Param{Errors}->{"ItemDueDate_" . $Item->{Position}};
        $Item->{DueDateSelect} = $LayoutObject->BuildDateSelection(
            %DateOpts,
            Prefix               => $Prefix,
            Format               => 'DateInputFormatLong',
            YearPeriodPast       => $YearsInPast,
            YearPeriodFuture     => 5,
            $Prefix . 'Class'    => $DueDateError || ' ',
            DiffTime             => 1,
            $Prefix . 'Optional' => 1,
        );

        if ( $DueDateError || $DateStartError ) {
            $Item->{SHOWDETAILS} = 1;
        }

        $LayoutObject->Block(
            Name => 'Item',
            Data => $Item,
        );

        if ( $UseAutocomplete ) {
            my $AutocompleteObject = $Kernel::OM->Get(
               'Kernel::System::PerlServices::TicketChecklist::Autocomplete::' . $AutocompleteModule
            );

            my $Fullname = $AutocompleteObject->Fullname(
                UserLogin => $Item->{ResponsibleKey} || $Item->{ResponsibleID},
            );

            $LayoutObject->Block(
                Name => 'ResponsibleAutocomplete',
                Data => {
                    %{$Item},
                    TextValue => $Fullname,
                    Value     => $Item->{ResponsibleKey} || $Item->{ResponsibleID},
                },
            );
        }

        if ( $ShowChangeNote ) {
            my $BlockSuffix = $EditChangeNote ? 'Edit' : '';
            $LayoutObject->Block(
                Name => 'ChangeNote' . $BlockSuffix,
                Data => $Item,
            );
        }
    }

    my $Output;

    # print header
    $Output .= $LayoutObject->Header(
        Type => 'Small',
    );

    my @UserGroups   = $GroupObject->GroupMemberList(
        UserID => $Self->{UserID},
        Result => 'ID',
        Type   => 'rw',
    );

    my %TemplateList = $TemplateObject->TemplateList(
        GroupIDs    => [ @UserGroups ],
        Valid       => 1,
        CustomerIDs => [ $Ticket{CustomerID} ],
    );

    $Param{TemplateSelect} = $LayoutObject->BuildSelection(
        Name         => 'ChecklistTemplate',
        Data         => \%TemplateList,
        PossibleNone => 1,
        Class        => 'Modernize',
    );

    my $Theme = $ConfigObject->Get('TicketChecklist::Theme') || 'Standard';
    my $Slim  = $Theme eq 'Slim' ? 'Slim' : '';

    $Output .= $LayoutObject->Output(
        TemplateFile => 'AgentTicketChecklist' . $Slim,
        Data         => {
            %Ticket,
            %Param,
            Position         => $Counter-1,
            ChangeNote       => $ShowChangeNote,
            ChangeNoteWidget => $ShowChangeNoteWidget,
            UseAutocomplete  => $UseAutocomplete,
        },
    );

    $LayoutObject->{HasDatepicker} = 1;
    $Output .= $LayoutObject->Footer(
        Type => 'Small',
    );

    return $Output;
}

# Prefill values for BuildDateSelection from a stored time stamp. Stored dates are
# in OTOBO time and are passed on unchanged: BuildDateSelection converts them to
# the user's time zone itself, and saving converts back via TransformDateSelection.
sub _DateSelectionValues {
    my ( $Self, %Param ) = @_;

    my $DateTimeObject = $Kernel::OM->Create(
        'Kernel::System::DateTime',
        ObjectParams => {
            String => $Param{TimeStamp},
        },
    );
    return if !$DateTimeObject;

    my $Values = $DateTimeObject->Get();

    return map { $Param{Prefix} . $_ => $Values->{$_} } qw(Minute Hour Day Month Year);
}

1;
