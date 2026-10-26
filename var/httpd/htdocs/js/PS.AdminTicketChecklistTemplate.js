// --
// PS.AdminTicketChecklistTemplate.js
// --
// This software comes with ABSOLUTELY NO WARRANTY. For details, see
// the enclosed file COPYING for license information (AGPL). If you
// did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
// --

"use strict";

var PS = PS || {};

/**
 * @namespace
 * @exports TargetNS as PS.TicketChecklist
 * @description
 *      This namespace contains the special module functions for the time tracking add on
 */
PS.AdminTicketChecklistTemplate = (function (TargetNS) {

    var BaseURL       = window.location.href.replace( window.location.search, "" );
    var ToggleState   = 0;
    var CustomerPos   = 0;
    var ItemNames     = {};
    var ExistingItems = {};
    var ExistingNames = {};
    var ActionPos     = 0;

    function ToggleAllDiv() {
        if ( ToggleState ) {
            $('span[id^="InfoMore_"]').removeClass( 'fa-eye-slash' ).addClass( 'fa-eye' );
            $('div[id^="Info_"]').addClass('Hidden');
            ToggleState = 0;
        }
        else {
            $('span[id^="InfoMore_"]').removeClass( 'fa-eye' ).addClass( 'fa-eye-slash' );
            $('div[id^="Info_"]').removeClass('Hidden');
            ToggleState = 1;
            Core.UI.InputFields.Activate();
        }

        return false;
    }

    TargetNS.InitItemNames = function() {
        $('.ItemTitle').each( function( TitleIndex, TitleField ) {
            var Name = $(this).val();
            var Pos  = $(this).attr('id').match(/\d+/);

            var Position            = Pos[0];
            ExistingItems[Position] = 1;
            ExistingNames[Name]     = 1;
            ItemNames[Position]     = Name;
        });
    };

    TargetNS.Init = function() {
        $('#ToggleAllBtn').bind( 'click', ToggleAllDiv );

        $('#AddBtn').bind( 'click', function() {
            NewItem();
            return false;
        });

        $('#AddActionBtn').bind( 'click', function() {
            TargetNS.NewAction();
            return false;
        });

        $('#Submit').bind( 'click', function() {
            $('#ItemCount').val(Positions);
            var ItemOrder = new Array;

            var Index = 0;
            $('li[id^="Item_"]').each( function() {
                ItemOrder[Index++] = $(this).attr('id').replace('Item_','');
            });

            $('#ItemOrder').val( ItemOrder.join(',') );

        });

        $('button[name="DelBtn"]').bind( 'click', function() {
            var Pos       = $(this).attr('id').match( /\d+/ );
            var ID        = $(this).siblings( 'input[id="ItemID_' + Pos[0] + '"]' );
            var Name      = $('#ItemTitle_' + Pos[0] ).val();

            if ( Core.Config.Get('Action') == 'AdminTicketChecklistTemplates' ) {
                $('#Item_' +  Pos ).remove();
                return false;
            }

            $(this).parent().parent().remove();

            var Position            = Pos[0];
            ItemNames[Position]     = Name;
            ExistingItems[Position] = 0;
            RedrawActionItemSelect();

            return false;
        });

        $('span[id^="Arrow"]').bind( 'click', MoveItem );
        $('span[id^="InfoMore"]').bind( 'click', ToggleMoreDiv );

        RedrawActionItemSelect();

        $('.ItemTitle' ).bind('change', function() {
            var Name     = $(this).val();
            var Pos      = $(this).attr('id').match(/\d+/);
            var Position = Pos[0];

            if ( ExistingNames[Name] > 0 ) {
                console.debug( "Name " + Name + " already exists" );
            }
            else {
                ItemNames[Position] = Name;
                ExistingItems[Position] = 1;
                RedrawActionItemSelect();
            }
        });

        Core.UI.DnD.Sortable(
            $('#ChecklistActions'),
            {
                Handle: '.Header h2',
                Items: '.CanDrag',
                Axis: 'y',
                Placeholder: 'DropPlaceholder',
                Tolerance: 'pointer',
                Distance: 15,
                Opacity: 0.6,
                Update: function () {
                    console.debug( 'Update' );
                }
            }
        );

    };


    TargetNS.NewAction = function(Data) {
        var NewNr      = ++ActionPos;
        var RawAction  = $('#ConditionActionTemplate').clone().html();
        var ActionItem = RawAction.replace( /#Nr/g, NewNr ).replace(/ParameterList/, NewNr );

        $('#ChecklistActions').append(
            ActionItem
        );

        $('#RemoveActionBtn' + NewNr ).bind('click', function() {
            $('#Action_' + NewNr).parent().remove();
        });

        $('#AddParamBtn_' + NewNr).bind('click', function() {
            NewActionParam(NewNr);
            return false;
        });

        // add options to ActionItem select

        Core.UI.InputFields.InitSelect( $('#ActionStatus_' + NewNr) );
        Core.UI.InputFields.InitSelect( $('#ActionModule_' + NewNr) );

        RedrawActionItemSelect();
        Core.UI.InputFields.InitSelect( $('#ActionItem_' + NewNr) );

        if ( Data && typeof( Data ) !== "undefined" ) {
            $('#ActionStatus_' + NewNr ).val( Data.ActionStatus );
            $('#ActionStatus_' + NewNr ).trigger('redraw.InputField');
            $('#ActionItem_' + NewNr ).val( Data.ActionItem );
            $('#ActionItem_' + NewNr ).trigger('redraw.InputField');
            $('#ActionModule_' + NewNr ).val( Data.ActionModule );
            $('#ActionModule_' + NewNr ).trigger('redraw.InputField');

            $('#ActionParams_' + NewNr + ' > .Field').remove();

            $.each( Data.ActionParams, function (pIndex, pValues) {
                NewActionParam( NewNr, pValues );
            });
        }
    };

    function NewActionParam( NewNr, Data ) {
        var OrigParam = $('#ActionParams_ParameterList').clone().html();
        var Pos       = $('#ActionParams_' + NewNr + ' > .Field').length + 1;

        var NewParam = OrigParam.replace(/#Nr_1/g, NewNr + '_' + Pos).replace(/#Nr/g, NewNr);
        if ( Pos != 1 ) {
            NewParam = NewParam.replace( /<button.*<\/button>/, '' );
        }

        $('#ActionParams_' + NewNr).append( NewParam );

        if ( Pos == 1 ) {
            $('#AddParamBtn_' + NewNr).bind('click', function() {
                NewActionParam(NewNr);
                return false;
            });
        }

        if ( Data && typeof( Data ) !== "undefined" ) {
            $('#ActionParamKey_' + NewNr + '_' + Pos).val( Data[0] );
            $('#ActionParamValue_' + NewNr + '_' + Pos).val( Data[1] );
        }
    }

    function NewItem () {
        var NewPos   = ( parseInt(Positions, 10) || 0 ) + 1;
        var RawItem  = $('#ItemTemplate').clone().html();
        var ListItem = RawItem.replace(/#Nr/g, NewPos );

        $('#ChecklistItems').append(
            ListItem
        );

        // add event listeners
        $('#DelBtn_' + NewPos ).bind( 'click', function() {
            $('#Item_' + NewPos ).remove();
        });

        $('#ArrowUp_' + NewPos ).bind( 'click', MoveItem );
        $('#ArrowDown_' + NewPos ).bind( 'click', MoveItem );
        $('#InfoMore_' + NewPos ).bind( 'click', ToggleMoreDiv );

        Core.UI.InputFields.InitSelect( $('#ItemStatus_' + NewPos) );
        Core.UI.InputFields.InitSelect( $('#ItemPriority_' + NewPos) );

        var UseAutocomplete = Core.Config.Get( 'UseAutocomplete' );

        if ( UseAutocomplete && UseAutocomplete == 1 ) {
            TargetNS.AutocompleteInit( $( '#ResponsibleSearchField_' + NewPos ), 'ResponsibleSearch', 'Responsible_' + NewPos );
        }
        else {
            Core.UI.InputFields.InitSelect( $('#ItemResponsible_' + NewPos) );
        }

        $('#ItemTitle_' + NewPos ).unbind('change' );
        $('#ItemTitle_' + NewPos ).bind('change', function() {
            var Name = $(this).val();

            if ( ExistingNames[Name] > 0 ) {
                console.debug( "Name " + Name + " already exists" );
            }
            else {
                ItemNames[NewPos] = Name;
                ExistingItems[NewPos] = 1;
                RedrawActionItemSelect();
            }
        });

        Positions = NewPos;
    };

    function RedrawActionItemSelect() {
        $('.ActionItemSelect').each( function() {
            var ID = $(this).attr('id').replace('ActionItem_', '');

            if ( ID == '#Nr' ) {
                return;
            }

            var Selected = $(this).val();
            var DropDown = $(this);

            $(this).find('option').remove();

            var NullOption = new Option( '-', '0' );
            DropDown.append( NullOption );

            $.each( ExistingItems, function( Position, IsValid ) {
                if ( IsValid == 0 ) {
                    return;
                }

                var ItemName   = ItemNames[Position];
                var ItemOption = new Option( ItemName, ItemName );
                DropDown.append( ItemOption );
            });

            $(this).val( Selected );
            DropDown.trigger('redraw.InputFields');
        });
    }


    function MoveItem () {
        
        var IsUp   = 0;
        if ( $(this).attr('id').match( /Up/ ) ) {
            IsUp   = 1;
        } 

        var ItemToMove = $(this).parent();

        if ( IsUp ) {
            ItemToMove.insertBefore( ItemToMove.prev() );
        }
        else {
            ItemToMove.insertAfter( ItemToMove.next() );
        }
    }

    function ToggleMoreDiv() {
        var ID = $(this).attr('id').replace( 'InfoMore_', '' );

        var MoreDiv = $('#Info_' + ID);
        if ( $(this).hasClass('fa-eye-slash') ) {
            $(this).removeClass('fa-eye-slash');
            $(this).addClass('fa-eye');
            MoreDiv.removeClass('Hidden');
            Core.UI.InputFields.Activate();
        }
        else {
            $(this).addClass('fa-eye-slash');
            $(this).removeClass('fa-eye');
            MoreDiv.addClass('Hidden');
        }
    }

    TargetNS.AddCustomer = function(Event, UI) {
        $('#CustomerID').val('');
        TargetNS.ShowCustomer( UI.item.label, UI.item.value );
    };

    TargetNS.ShowCustomer = function ( Label, Value ) {
        console.debug( Label + ' // ' + Value );
        console.debug( CustomerPos );

        CustomerPos++;
        var CustomerID = $('#CustomerIDTemplate').clone().html().replace(/#Nr/g, CustomerPos);
        $('#CustomerIDsDiv').append( CustomerID );

        $('#CustomerLabel-' + CustomerPos ).text( Label );
        $('#Customer-' + CustomerPos + ' > input').val( Value );
        $('#CustomerDelete-' + CustomerPos ).bind( 'click', function(){ $(this).parent().parent().parent().remove() } );
    };

    TargetNS.AutocompleteInit = function ($Input, FrontendSubaction, TargetField, FrontendAction, Callback) {
        var Keyword = 'Responsible';

        if ( TargetField && TargetField != '' ) {
            Keyword = TargetField;
        }

        var AutocompleteCallback = function (Event, UI) {
            $('#' + Keyword ).val(UI.item.value);
            $Input.val(UI.item.label);
        };

        if ( typeof Callback == 'function' ) {
            AutocompleteCallback = Callback;
        }

        Core.UI.Autocomplete.Init($Input, function (Request, Response) {
                var URL = Core.Config.Get('Baselink'), Data = {
                    Action: FrontendAction || 'AgentTicketChecklistResponsibleSearch',
                    Term: Request.term,
                    Subaction: FrontendSubaction
                };

                if (!Core.Config.Get('SessionIDCookie')) {
                    Data[Core.Config.Get('SessionName')] = Core.Config.Get('SessionID');
                    Data[Core.Config.Get('CustomerPanelSessionName')] = Core.Config.Get('SessionID');
                }

                $Input.data('AutoCompleteXHR', Core.AJAX.FunctionCall(URL, Data, function (Result) {
                    var Data = [];
                    $Input.removeData('AutoCompleteXHR');
                    $.each(Result, function () {
                        Data.push({
                            label: this.Label,
                            value: this.Value
                        });
                    });
                    Response(Data);
                }));
        }, 
        AutocompleteCallback,
        Keyword + 'Search');
    };

    return TargetNS;
}(PS.AdminTicketChecklistTemplate || {}));
