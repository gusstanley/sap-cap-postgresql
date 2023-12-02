using {managed} from '@sap/cds/common';

namespace sap.postgres.bookshop;

entity Books : managed {
    key ID    : UUID @(Core.Computed: true);
        title : String(111);
        price : Double;
        authorName: String(255)
}
