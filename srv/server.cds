using { sap.postgres.bookshop as my } from '../db/schema';

service MyService { 
  entity Books as projection on my.Books;
}