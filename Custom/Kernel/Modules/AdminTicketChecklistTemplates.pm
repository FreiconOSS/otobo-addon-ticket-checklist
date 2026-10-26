# --
# Copyright (C) 2014 - 2022 Perl-Services.de, https://www.perl-services.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AdminTicketChecklistTemplates;

use strict;
use warnings;

use File::Spec;
use File::Basename;

our @ObjectDependencies = qw(
    Kernel::System::PerlServices::TicketChecklistTemplate
    Kernel::System::PerlServices::TicketChecklistStatus
    Kernel::System::Priority
    Kernel::System::Valid
    Kernel::System::Group
    Kernel::System::Web::Request
    Kernel::Output::HTML::Layout
    Kernel::Config
    Kernel::System::Main
    Kernel::System::JSON
    Kernel::System::User
    Kernel::System::Time
    Kernel::System::CustomerCompany
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $ConfigObject   = $Kernel::OM->Get('Kernel::Config');
    my $TemplateObject = $Kernel::OM->Get('Kernel::System::PerlServices::TicketChecklistTemplate');
    my $ValidObject    = $Kernel::OM->Get('Kernel::System::Valid');
    my $JSONObject     = $Kernel::OM->Get('Kernel::System::JSON');
    my $ParamObject    = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $LayoutObject   = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $CompanyObject  = $Kernel::OM->Get('Kernel::System::CustomerCompany');

    my @Params = qw(ID Name ValidID ItemCount ItemOrder);
    my %GetParam;
    for my $Param (@Params) {
        $GetParam{$Param} = $ParamObject->GetParam( Param => $Param ) || '';
    }

    for my $ArrayParam ( qw/GroupIDs TemplateCustomerID/ ) {
        my @IDs = $ParamObject->GetArray( Param => $ArrayParam );

        $GetParam{$ArrayParam} = @IDs ? \@IDs : [];
    }

    if ( $GetParam{ItemOrder} ) {
        my @ItemParams = qw(Title Status Responsible DateStartDiff DueDateDiff Priority Comment);

        INDEX:
        for my $Index ( split /,/, $GetParam{ItemOrder} ) {
            my %ItemData;

            for my $Key ( @ItemParams ) {
                my $Param = sprintf "Item%s_%s", $Key, $Index;
                $ItemData{$Key} = $ParamObject->GetParam( Param => $Param ) || '';
            }

            $ItemData{ResponsibleKey} = $ParamObject->GetParam( Param => 'Responsible_' . $Index ) || '';

            next INDEX if !$ItemData{Title};

            push @{ $GetParam{Items} }, \%ItemData;
        }

        my @ParamNames  = $ParamObject->GetParamNames();
        my @ActionItems = grep{ $_ =~ m{ActionItem_\d+}xms }@ParamNames;

        my @Conditions;
        for my $Item ( @ActionItems ) {
            $Item =~ s{ActionItem_}{};

            my %Condition;
            for my $Key ( qw/ActionModule/ ) {
                $Condition{$Key} = $ParamObject->GetParam( Param => $Key . '_' . $Item );
            }

            for my $Key ( qw/ActionItem ActionStatus/ ) {
                $Condition{$Key} = [ $ParamObject->GetArray( Param => $Key . '_' . $Item ) ];
            }

            my @ActionParamsKeys = grep{ $_ =~ m{ActionParamKey_${Item}_\d+} }@ParamNames;
            my @ActionParams;

            for my $KeyNr ( @ActionParamsKeys ) {
                $KeyNr =~ s{ActionParamKey_${Item}_}{};

                my $KeyName   =  join '_', 'ActionParamKey', $Item, $KeyNr;
                my $ValueName =  join '_', 'ActionParamValue', $Item, $KeyNr;

                push @ActionParams, [
                    $ParamObject->GetParam( Param => $KeyName ),
                    $ParamObject->GetParam( Param => $ValueName ),
                ];
            }

            $Condition{ActionParams} = \@ActionParams;
            push @Conditions, \%Condition;
        }

        $GetParam{Conditions} = \@Conditions;
    }

    # ------------------------------------------------------------ #
    # get data 2 form
    # ------------------------------------------------------------ #
    if ( $Self->{Subaction} eq 'Edit' || $Self->{Subaction} eq 'Add' || $Self->{Subaction} eq 'Copy' ) {
        my %Subaction = (
            Edit => 'Update',
            Add  => 'Save',
            Copy => 'Save',
        );

        my $Output = $LayoutObject->Header();
        $Output .= $LayoutObject->NavigationBar();
        $Output .= $Self->_MaskForm(
            %GetParam,
            %Param,
            Subaction => $Subaction{ $Self->{Subaction} },
        );
        $Output .= $LayoutObject->Footer();
        return $Output;
    }

    # ------------------------------------------------------------ #
    # update action
    # ------------------------------------------------------------ #
    elsif ( $Self->{Subaction} eq 'Update' ) {

        # challenge token check for write action
        $LayoutObject->ChallengeTokenCheck();
 
        # server side validation
        my %Errors;
        if (
            !$GetParam{ValidID} ||
            !$ValidObject->ValidLookup( ValidID => $GetParam{ValidID} )
            )
        {
            $Errors{ValidIDInvalid} = 'ServerError';
        }

        for my $Param (qw(Name)) {
            if ( !$GetParam{$Param} ) {
                $Errors{ $Param . 'Invalid' } = 'ServerError';
            }
        }

        if ( %Errors ) {
            $Self->{Subaction} = 'Edit';

            my $Output = $LayoutObject->Header();
            $Output .= $LayoutObject->NavigationBar();
            $Output .= $Self->_MaskForm(
                %GetParam,
                %Param,
                %Errors,
                Subaction => 'Update',
            );
            $Output .= $LayoutObject->Footer();

            return $Output;
        }

        my $Update = $TemplateObject->TemplateUpdate(
            %GetParam,
            CustomerIDs => $GetParam{TemplateCustomerID},
            UserID      => $Self->{UserID},
        );

        if ( !$Update ) {
            return $LayoutObject->ErrorScreen();
        }

        return $LayoutObject->Redirect( OP => "Action=AdminTicketChecklistTemplates" );
    }

    # ------------------------------------------------------------ #
    # insert template
    # ------------------------------------------------------------ #
    elsif ( $Self->{Subaction} eq 'Save' ) {

        # challenge token check for write action
        $LayoutObject->ChallengeTokenCheck();

        # server side validation
        my %Errors;
        if (
            !$GetParam{ValidID} ||
            !$ValidObject->ValidLookup( ValidID => $GetParam{ValidID} )
            )
        {
            $Errors{ValidIDInvalid} = 'ServerError';
        }

        for my $Param (qw(Name ValidID)) {
            if ( !$GetParam{$Param} ) {
                $Errors{ $Param . 'Invalid' } = 'ServerError';
            }
        }

        if ( %Errors ) {
            $Self->{Subaction} = 'Add';

            my $Output = $LayoutObject->Header();
            $Output .= $LayoutObject->NavigationBar();
            $Output .= $Self->_MaskForm(
                %GetParam,
                %Param,
                %Errors,
                Subaction => 'Save',
            );
            $Output .= $LayoutObject->Footer();
            return $Output;
        }

        my $Success = $TemplateObject->TemplateAdd(
            %GetParam,
            CustomerIDs => $GetParam{TemplateCustomerID},
            UserID      => $Self->{UserID},
            OwnerID     => $GetParam{OwnerSelected},
        );

        if ( !$Success ) {
            return $LayoutObject->ErrorScreen();
        }

        return $LayoutObject->Redirect( OP => "Action=AdminTicketChecklistTemplates" );
    }

    elsif ( $Self->{Subaction} eq 'Import' ) {
        my $LanguageObject = $LayoutObject->{LanguageObject};

        my $DoOverride  = $ConfigObject->Get('TicketChecklist::OverrideExistingTemplatesOnImport');
        my %UploadStuff = $ParamObject->GetUploadAll(
            Param => 'TemplateFile',
        );

        if ( $UploadStuff{Filename} !~ m{\.json\z} || $UploadStuff{ContentType} !~ m{json} ) {
            return $LayoutObject->FatalError(
                Message => $LanguageObject->Translate( 'Please upload a JSON file' ),
            );
        }

        my $ListOfTemplates = $JSONObject->Decode( Data => $UploadStuff{Content} );

        if ( ref $ListOfTemplates ne 'ARRAY' ) {
            return $LayoutObject->FatalError(
                Message => $LanguageObject->Translate( 'JSON file does not contain an array of templates' ),
            );
        }

        TEMPLATE:
        for my $Template ( @{ $ListOfTemplates || [] } ) {
            my $Name = $Template->{Name};

            my $TemplateExists = $TemplateObject->TemplateNameExists( Name => $Name );

            next TEMPLATE if $TemplateExists && !$DoOverride;

            my $Method = $TemplateExists ? 'TemplateUpdate' : 'TemplateAdd';

            $TemplateObject->$Method(
                %{ $Template || {} },
                ID     => $TemplateExists,
                UserID => $Self->{UserID},
            );
        }

        return $LayoutObject->Redirect( OP => "Action=AdminTicketChecklistTemplates" );
    }

    elsif ( $Self->{Subaction} eq 'Export' ) {
        my $TimeObject = $Kernel::OM->Get('Kernel::System::Time');

        my ( $s, $m, $h, $D, $M, $Y ) = $TimeObject->SystemTime2Date(
            SystemTime => $TimeObject->SystemTime(),
        );

        my $Date     = sprintf "%04d-%02d-%02d_%02d-%02d", $Y, $M, $D, $h, $m;
        my $Filename = "TicketChecklistTemplates-$Date.json";

        my @TemplateIDs  = $ParamObject->GetArray( Param => 'ID' );
        my %TemplateList = $TemplateObject->TemplateList();

        if ( !@TemplateIDs ) {
            @TemplateIDs = keys %TemplateList;
        }

        my @TemplatesToExport;
        for my $TemplateID ( @TemplateIDs ) {
            next TEMPLATEID if !exists $TemplateList{$TemplateID};

            my %Template = $TemplateObject->TemplateGet( ID => $TemplateID );
            push @TemplatesToExport, \%Template;
        }

        my $JSON = $JSONObject->Encode( Data => \@TemplatesToExport );

        return $LayoutObject->Attachment(
            Filename    => $Filename,
            ContentType => "application/json; charset=" . $LayoutObject->{Charset},
            Content     => $JSON,
            Type        => 'attachment',
        );
    }

    elsif ( $Self->{Subaction} eq 'Delete' ) {
        $TemplateObject->TemplateDelete( %GetParam );

        return $LayoutObject->Redirect( OP => "Action=AdminTicketChecklistTemplates" );
    }

    elsif ( $Self->{Subaction} eq 'SearchCustomerID' ) {

        my $SearchTerm          = $ParamObject->GetParam( Param => 'Term' ) || '';
        my %CustomerCompanyList = $CompanyObject->CustomerCompanyList(
            Search => $SearchTerm,
        );

        my @Result;
        my %Seen;

        CUSTOMERID:
        for my $CustomerID ( sort keys %CustomerCompanyList ) {

            next CUSTOMERID if $Seen{$CustomerID}++;
            push @Result, {
                Label => $CustomerCompanyList{$CustomerID},
                Value => $CustomerID,
            };
        }

        my $JSON = $LayoutObject->JSONEncode(
            Data => \@Result,
        );

        return $LayoutObject->Attachment(
            ContentType => 'application/json; charset=' . $LayoutObject->{Charset},
            Content     => $JSON || '',
            Type        => 'inline',
            NoCache     => 1,
        );
    }


    # ------------------------------------------------------------ #
    # else ! print form
    # ------------------------------------------------------------ #
    else {
        my $Output = $LayoutObject->Header();
        $Output .= $LayoutObject->NavigationBar();
        $Output .= $Self->_MaskForm();
        $Output .= $LayoutObject->Footer();

        return $Output;
    }
}

sub _MaskForm {
    my ( $Self, %Param ) = @_;

    my $TemplateObject = $Kernel::OM->Get('Kernel::System::PerlServices::TicketChecklistTemplate');
    my $StatusObject   = $Kernel::OM->Get('Kernel::System::PerlServices::TicketChecklistStatus');
    my $ValidObject    = $Kernel::OM->Get('Kernel::System::Valid');
    my $GroupObject    = $Kernel::OM->Get('Kernel::System::Group');
    my $PriorityObject = $Kernel::OM->Get('Kernel::System::Priority');
    my $LayoutObject   = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ConfigObject   = $Kernel::OM->Get('Kernel::Config');
    my $UserObject     = $Kernel::OM->Get('Kernel::System::User');
    my $MainObject     = $Kernel::OM->Get('Kernel::System::Main');
    my $JSONObject     = $Kernel::OM->Get('Kernel::System::JSON');
    my $CompanyObject  = $Kernel::OM->Get('Kernel::System::CustomerCompany');
    my $LogObject      = $Kernel::OM->Get('Kernel::System::Log');

    if ( $Param{ID} && !$Param{ItemOrder} ) {
        my %Template = $TemplateObject->TemplateGet( ID => $Param{ID} );

        for my $Key ( keys %Template ) {
            $Param{$Key} = $Template{$Key}; # if !$Param{$Key};
        }

        $Param{TemplateCustomerID} = $Template{CustomerIDs};
    }

    my $UseAutocomplete    = $ConfigObject->Get('TicketChecklist::ResponsibleAutocomplete') ? 1 : 0;
    my $AutocompleteModule = $ConfigObject->Get('TicketChecklist::ResponsibleAutocompleteModule') // 'Agent';

    my $ValidID = $ValidObject->ValidLookup( Valid => 'valid' );

    $Param{ValidSelect} = $LayoutObject->BuildSelection(
        Data       => { $ValidObject->ValidList() },
        Name       => 'ValidID',
        Size       => 1,
        SelectedID => $Param{ValidID} || $ValidID,
        HTMLQuote  => 1,
        Class      => 'Modernize',
    );

    $Param{GroupIDSelect} = $LayoutObject->BuildSelection(
        Data       => { $GroupObject->GroupList( Valid => 1 ) },
        Name       => 'GroupIDs',
        Size       => 5,
        SelectedID => $Param{GroupIDs},
        Multiple   => 1,
        Class      => 'Modernize',
    );

    if ( $Self->{Subaction} ne 'Edit' && $Self->{Subaction} ne 'Add' ) {

        my %TemplateList = $TemplateObject->TemplateList();
  
        if ( !%TemplateList ) {
            $LayoutObject->Block(
                Name => 'NoTemplateFound',
            );
        }

        for my $TemplateID ( sort { $TemplateList{$a} cmp $TemplateList{$b} } keys %TemplateList ) {
            my %Template = $TemplateObject->TemplateGet(
                ID => $TemplateID,
            );

            $LayoutObject->Block(
                Name => 'TemplateRow',
                Data => \%Template,
            );
        }
    }

    # show customer ids
    for my $CustomerID ( sort @{ $Param{TemplateCustomerID} || [] } ) {
        my  %CustomerCompany = $CompanyObject->CustomerCompanyGet(
            CustomerID => $CustomerID,
        );

        $LayoutObject->Block(
            Name => 'CustomerID',
            Data => {
                Label => $CustomerID . ' ' . $CustomerCompany{CustomerCompanyName},
                Value => $CustomerID,
            },
        );
    }

    my $DefaultStatus    = $ConfigObject->Get('TicketChecklist::DefaultState');
    my %StatusList       = $StatusObject->TicketChecklistStatusList();
    $Param{StatusSelect} = $LayoutObject->BuildSelection(
        Data          => \%StatusList,
        Name          => 'ItemStatus_#Nr',
        Size          => 1,
        Translation   => 1,
        SelectedValue => $DefaultStatus,
        Class         => 'Modernize',
    );

    my $DefaultPriority    = $ConfigObject->Get('TicketChecklist::DefaultPriority');
    my %PriorityList       = $PriorityObject->PriorityList( Valid => 1 );
    $Param{PrioritySelect} = $LayoutObject->BuildSelection(
        Data          => \%PriorityList,
        Name          => 'ItemPriority_#Nr',
        Size          => 1,
        Translation   => 1,
        SelectedValue => $DefaultPriority,
        Class         => 'Modernize',
    );

    my %UserList = $UserObject->UserList(
        Type  => 'Long',
        Valid => 1,
    );
    $Param{ResponsibleSelect} = $LayoutObject->BuildSelection(
        Data          => \%UserList,
        Name          => 'ItemResponsible_#Nr',
        Size          => 1,
        PossibleNone  => 1,
        Class         => 'Modernize',
    );

    my $Position = 1;
    for my $Item ( @{ $Param{Items} || [] } ) {
        my $StatusSelect = $LayoutObject->BuildSelection(
            Data        => \%StatusList,
            Name        => 'ItemStatus_' . $Position,
            SelectedID  => $Item->{Status},
            Size        => 1,
            Translation => 1,
            Class       => 'Modernize',
        );
    
        my $PrioritySelect = $LayoutObject->BuildSelection(
            Data        => \%PriorityList,
            Name        => 'ItemPriority_' . $Position,
            SelectedID  => $Item->{Priority},
            Size        => 1,
            Translation => 1,
            Class       => 'Modernize',
        );
    
        my $UserSelect = $LayoutObject->BuildSelection(
            Data          => \%UserList,
            Name          => 'ItemResponsible_' . $Position,
            Size          => 1,
            PossibleNone  => 1,
            SelectedID    => $Item->{Responsible},
            Class         => 'Modernize',
        );

        if ( $UseAutocomplete ) {
            $UserSelect = '';
        }

        $LayoutObject->Block(
            Name => 'Item',
            Data => {
                %{$Item},
                ResponsibleSelect => $UserSelect,
                PrioritySelect    => $PrioritySelect,
                StatusSelect      => $StatusSelect,
                Position          => $Position,
            },
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
                    Position  => $Position,
                },
            );
        }

        $Position++;
    }

    # lookup existing Transition Actions on disk
    my $Directory = File::Spec->catdir(
        $ConfigObject->Get('Home'),
       qw/Kernel System PerlServices TicketChecklist ConditionAction/,
    );

    my @List = $MainObject->DirectoryRead(
        Directory => $Directory,
        Filter    => '*.pm',
    );

    my %ActionModules;
    my $BasePackagename = 'Kernel::System::PerlServices::TicketChecklist::ConditionAction::';

    ITEM:
    for my $Item (@List) {

        # remove .pm
        my $Basename = basename $Item;
        $Basename =~ s{\.pm\z}{};

        next ITEM if $Basename eq 'Base';

        $ActionModules{ $BasePackagename . $Basename } = $Basename;
    }

    my %Opts = (
        Size          => 1,
        SelectedValue => $DefaultStatus,
    );

    if ( $ConfigObject->Get('TicketChecklist::Condition::MultiState') ) {
        %Opts = (
            Size          => 5,
            SelectedValue => $DefaultStatus,
            Multiple      => 1,
        );
    }

    $Param{ActionStatusSelect} = $LayoutObject->BuildSelection(
        Data        => \%StatusList,
        Name        => 'ActionStatus_#Nr',
        Translation => 1,
        Class       => 'Modernize',
        %Opts,
    );

    $Param{ActionModuleSelect} = $LayoutObject->BuildSelection(
        Data         => \%ActionModules,
        Name         => 'ActionModule_#Nr',
        PossibleNone => 1,
        Class        => 'Modernize Validate_Required ',
    );

    for my $Action ( @{ $Param{Conditions} || [] } ) {
        my $ActionJSON = $JSONObject->Encode( Data => $Action );

        $LayoutObject->Block(
            Name => 'Action',
            Data => {
                Action => $ActionJSON,
            },
        );
    }


    $Param{SubactionName} = 'Update';
    $Param{SubactionName} = 'Save' if $Self->{Subaction} && ( $Self->{Subaction} eq 'Add' || $Self->{Subaction} eq 'Copy' );

    $Param{Positions} = $Position - 1;

    my $TemplateFile = 'AdminTicketChecklistTemplateList';
    $TemplateFile = 'AdminTicketChecklistTemplateForm' if $Self->{Subaction};

    if ( $UseAutocomplete ) {
        $Param{ResponsibleSelect} = '';

        $LayoutObject->Block( Name =>  'ResponsibleAutocompleteTemplate' );
    }

    return $LayoutObject->Output(
        TemplateFile => $TemplateFile,
        Data         => \%Param
    );
}

1;
